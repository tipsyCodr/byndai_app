import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditEventScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;
  final VoidCallback onEventUpdated;

  const EditEventScreen({
    super.key,
    required this.eventData,
    required this.onEventUpdated,
  });

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isInitializing = true;
  final List<dynamic> _existingImages = [];
  final List<XFile?> _selectedNewImages = [];
  final List<String> _imagesToDelete = [];
  final ImagePicker _picker = ImagePicker();
  String? _selectedStateName;
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _filteredDistricts = [];

  List<IndustryModel> industries = [];
  int? selectedIndustryId;
  bool isIndustryLoading = false;

  // Form Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _timingController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _maxAttendeesController = TextEditingController();
  final TextEditingController _eventTypeController = TextEditingController();

  // Dropdown Values
  String? _selectedCountry;
  int? _selectedState;
  String? _selectedDistrict;
  String? _selectedIsAudience;
  String? _selectedIsOnline;
  String? _selectedStatus;

  // Lists for dropdowns
  List<Map<String, dynamic>> _states = [];

  bool _isIndustryLoading = false;

  // Validation Keys
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _imageBaseUrl =
      "https://powderblue-jellyfish-554082.hostingersite.com";

  // ================= HEADERS =================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _getHeadersMultipart() async {
    final token = await UserStorageService().getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= INITIALIZE FORM WITH EVENT DATA =================
  void _initializeFormData() {
    final event = widget.eventData;

    // Set basic info
    _titleController.text = event['title'] ?? '';
    _descriptionController.text = event['description'] ?? '';
    _linkController.text = event['link'] ?? '';

    // Set dates
    if (event['start_date'] != null) {
      _startDateController.text = event['start_date'];
    }
    if (event['end_date'] != null) {
      _endDateController.text = event['end_date'];
    }

    // Set timing
    if (event['timing'] != null) {
      _timingController.text = event['timing'];
    }

    // Set industry
    if (event['industry'] != null && event['industry']['id'] != null) {
      selectedIndustryId = event['industry']['id'];
    }

    // Set location
    if (event['location'] != null) {
      _locationController.text = event['location'];
    }

    // Set event type
    if (event['event_type'] != null) {
      _eventTypeController.text = event['event_type'];
    }

    // Set max attendees
    if (event['max_attendees'] != null) {
      _maxAttendeesController.text = event['max_attendees'].toString();
    }

    // Set dropdown values
    if (event['is_audience'] != null) {
      _selectedIsAudience = event['is_audience'].toString();
    }

    if (event['is_online'] != null) {
      _selectedIsOnline = event['is_online'].toString();
    }

    if (event['status'] != null) {
      _selectedStatus = event['status'].toString();
    }

    // Set country, state, district
    if (event['country'] != null && event['country']['id'] != null) {
      _selectedCountry = event['country']['id'].toString();
    }

    if (event['state'] != null && event['state']['id'] != null) {
      _selectedState = event['state']['id'];
      _selectedStateName = event['state']['state_name'];
    }

    if (event['district'] != null && event['district']['id'] != null) {
      _selectedDistrict = event['district']['id'].toString();
    }

    // Set existing images
    if (event['images'] != null && event['images'] is List) {
      _existingImages.addAll(event['images']);
    }
  }

  // ================= API CALLS =================
  Future<void> _fetchIndustries() async {
    try {
      setState(() => isIndustryLoading = true);

      final uri = Uri.parse("$_baseUrl/industries");
      final response = await http.get(uri, headers: await _getHeaders());

      debugPrint("========== INDUSTRY API ==========");
      debugPrint("URL: $uri");
      debugPrint("STATUS: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == true) {
          final list = jsonData['data'] as List;
          setState(() {
            industries = list.map((e) => IndustryModel.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Industry fetch error: $e");
    } finally {
      setState(() => isIndustryLoading = false);
    }
  }

  Future<void> _fetchStates() async {
    try {
      final uri = Uri.parse("$_baseUrl/states");
      final response = await http.get(uri, headers: await _getHeaders());

      debugPrint("========== STATES API ==========");
      debugPrint("URL: $uri");
      debugPrint("STATUS: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData["status"] == true) {
          final List list = jsonData["data"];
          setState(() {
            _states = list.map((e) {
              return {
                "id": e["id"],
                "state_name": e["state_name"],
                "c_id": e["c_id"],
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("States fetch error: $e");
    }
  }

  Future<void> _fetchDistricts() async {
    try {
      final uri = Uri.parse("$_baseUrl/districts");
      final response = await http.get(uri, headers: await _getHeaders());

      debugPrint("========== DISTRICTS API ==========");
      debugPrint("URL: $uri");
      debugPrint("STATUS: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData["status"] == true) {
          final List list = jsonData["data"];
          setState(() {
            _districts = list.map((e) {
              return {
                "id": e["id"],
                "district_name": e["district_name"],
                "s_id": e["s_id"],
              };
            }).toList();

            // Filter districts based on selected state
            if (_selectedState != null) {
              _filteredDistricts =
                  _districts.where((d) => d["s_id"] == _selectedState).toList();
            } else {
              _filteredDistricts = [];
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Districts fetch error: $e");
    }
  }

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _initializeFormData();
    _initializeData();
  }

  void _initializeData() async {
    await Future.wait([
      _fetchIndustries(),
      _fetchStates(),
      _fetchDistricts(),
    ]);
    setState(() => _isInitializing = false);
  }

  // ================= STEPPER CONTROLS =================
  void _nextStep() {
    if (_currentStep < 3 && _validateCurrentStep()) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_titleController.text.isEmpty) {
          _showError('Please enter event title');
          return false;
        }
        if (_startDateController.text.isEmpty) {
          _showError('Please select start date');
          return false;
        }
        return true;
      case 1:
        if (selectedIndustryId == null) {
          _showError('Please select industry');
          return false;
        }
        return true;
      case 2:
        return true;
      case 3:
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ================= IMAGE MANAGEMENT =================
  Future<void> _pickNewImage(int index) async {
    final XFile? selected =
        await _picker.pickImage(source: ImageSource.gallery);
    if (selected != null) {
      setState(() {
        if (_selectedNewImages.length > index) {
          _selectedNewImages[index] = selected;
        } else {
          _selectedNewImages.add(selected);
        }
      });
    }
  }

  void _addImageField() {
    if (_existingImages.length + _selectedNewImages.length < 5) {
      setState(() {
        _selectedNewImages.add(null);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 images allowed')),
      );
    }
  }

  void _removeExistingImage(int index) {
    final image = _existingImages[index];
    if (image['event_img_path'] != null) {
      _imagesToDelete.add(image['event_img_path']);
    }
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImageField(int index) {
    setState(() {
      _selectedNewImages.removeAt(index);
    });
  }

  // ================= DATE PICKERS =================
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      if (isStartDate) {
        _startDateController.text = formattedDate;
      } else {
        _endDateController.text = formattedDate;
      }
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      _timingController.text = '$hour:$minute:00';
    }
  }

  // ================= UPDATE EVENT API =================
  Future<void> _updateEvent() async {
    if (!_validateCurrentStep()) return;

    final validNewImages =
        _selectedNewImages.where((img) => img != null).toList();

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse("$_baseUrl/update-event/${widget.eventData['id']}");
      final request = http.MultipartRequest("POST", uri);

      // headers
      request.headers.addAll(await _getHeadersMultipart());

      // fields
      request.fields['title'] = _titleController.text.trim();
      request.fields['description'] = _descriptionController.text.trim();
      request.fields['start_date'] = _startDateController.text.trim();

      if (selectedIndustryId != null) {
        request.fields['indus_type'] = selectedIndustryId.toString();
      }

      if (_descriptionController.text.trim().isNotEmpty) {
        request.fields['description'] = _descriptionController.text.trim();
      }

      if (_linkController.text.trim().isNotEmpty) {
        request.fields['link'] = _linkController.text.trim();
      }

      if (_endDateController.text.trim().isNotEmpty) {
        request.fields['end_date'] = _endDateController.text.trim();
      }

      if (_timingController.text.trim().isNotEmpty) {
        request.fields['timing'] = _timingController.text.trim();
      }

      if (_selectedCountry != null) {
        request.fields['country_id'] = _selectedCountry!;
      }

      if (_selectedState != null) {
        request.fields['state_id'] = _selectedState.toString();
      }

      if (_selectedDistrict != null) {
        request.fields['district_id'] = _selectedDistrict!;
      }

      if (_locationController.text.trim().isNotEmpty) {
        request.fields['location'] = _locationController.text.trim();
      }

      if (_eventTypeController.text.trim().isNotEmpty) {
        request.fields['event_type'] = _eventTypeController.text.trim();
      }

      if (_maxAttendeesController.text.trim().isNotEmpty) {
        request.fields['max_attendees'] = _maxAttendeesController.text.trim();
      }

      if (_selectedIsAudience != null) {
        request.fields['is_audience'] = _selectedIsAudience!;
      }

      if (_selectedIsOnline != null) {
        request.fields['is_online'] = _selectedIsOnline!;
      }

      if (_selectedStatus != null) {
        request.fields['status'] = _selectedStatus!;
      }

      // Add images to delete
      for (var imgPath in _imagesToDelete) {
        request.fields['delete_images[]'] = imgPath;
      }

      // Add new images
      for (int i = 0; i < validNewImages.length; i++) {
        final img = validNewImages[i]!;
        final bytes = await img.readAsBytes();

        request.files.add(
          http.MultipartFile.fromBytes(
            "event_img[]",
            bytes,
            filename: img.name,
            contentType: MediaType("image", "jpeg"),
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);

      debugPrint("========== UPDATE EVENT API ==========");
      debugPrint("STATUS CODE: ${response.statusCode}");
      debugPrint("RESPONSE: $jsonResponse");

      if (response.statusCode == 200 && jsonResponse['status'] == true) {
        _showSuccess(jsonResponse['message'] ?? "Event updated successfully!");
        widget.onEventUpdated();
        Navigator.pop(context);
      } else {
        _showError(jsonResponse['message'] ?? "Failed to update event");
      }
    } catch (e) {
      debugPrint("EXCEPTION: $e");
      _showError("Error updating event: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ================= BUILD STEPPER =================
  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Basic Info', style: TextStyle(color: Colors.white)),
        content: _buildStep1(),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Location & Timing',
            style: TextStyle(color: Colors.white)),
        content: _buildStep2(),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title:
            const Text('Event Details', style: TextStyle(color: Colors.white)),
        content: _buildStep3(),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title:
            const Text('Manage Images', style: TextStyle(color: Colors.white)),
        content: _buildStep4(),
        isActive: _currentStep >= 3,
        state: StepState.indexed,
      ),
    ];
  }

  // ================= STEP 1: BASIC INFO =================
  Widget _buildStep1() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Title
          TextFormField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Event Title *',
              labelStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              filled: true,
              fillColor: Colors.grey[900],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter event title';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Description',
              labelStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              filled: true,
              fillColor: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),

          // Link
          TextFormField(
            controller: _linkController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Event Link (URL)',
              labelStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              filled: true,
              fillColor: Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),

          // Start Date
          TextFormField(
            controller: _startDateController,
            style: const TextStyle(color: Colors.white),
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Start Date *',
              labelStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              filled: true,
              fillColor: Colors.grey[900],
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.grey),
                onPressed: () => _selectDate(context, true),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select start date';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // End Date
          TextFormField(
            controller: _endDateController,
            style: const TextStyle(color: Colors.white),
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'End Date (Optional)',
              labelStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              filled: true,
              fillColor: Colors.grey[900],
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.grey),
                onPressed: () => _selectDate(context, false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= STEP 2: LOCATION & TIMING =================
  Widget _buildStep2() {
    return Column(
      children: [
        // Timing
        TextFormField(
          controller: _timingController,
          style: const TextStyle(color: Colors.white),
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Event Timing (Optional)',
            labelStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade600),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            filled: true,
            fillColor: Colors.grey[900],
            suffixIcon: IconButton(
              icon: const Icon(Icons.access_time, color: Colors.grey),
              onPressed: _selectTime,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Industry Type Dropdown
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade600),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<int>(
              value: selectedIndustryId,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              decoration: InputDecoration(
                labelText: "Industry Type *",
                labelStyle: const TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: industries.map((industry) {
                return DropdownMenuItem<int>(
                  value: industry.id,
                  child: Text(
                    industry.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedIndustryId = value;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // State
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<int>(
              value: _selectedState,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              decoration: InputDecoration(
                labelText: "State",
                labelStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: _states.map((state) {
                return DropdownMenuItem<int>(
                  value: state['id'],
                  child: Text(
                    state['state_name'],
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                final selectedState =
                    _states.firstWhere((state) => state['id'] == value);

                setState(() {
                  _selectedState = value;
                  _selectedStateName = selectedState['state_name'];
                  _selectedDistrict = null;
                  _filteredDistricts =
                      _districts.where((d) => d["s_id"] == value).toList();
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // District
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade600),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedDistrict,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              decoration: InputDecoration(
                labelText: 'District',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: _filteredDistricts.map((district) {
                return DropdownMenuItem(
                  value: district['id'].toString(),
                  child: Text(
                    district['district_name'],
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (_selectedState == null)
                  ? null
                  : (value) {
                      setState(() => _selectedDistrict = value);
                    },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Location
        TextFormField(
          controller: _locationController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Location/Venue',
            labelStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade600),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            filled: true,
            fillColor: Colors.grey[900],
          ),
        ),
      ],
    );
  }

  // ================= STEP 3: EVENT DETAILS =================
  Widget _buildStep3() {
    return Column(
      children: [
        // Max Attendees
        TextFormField(
          controller: _maxAttendeesController,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Max Attendees',
            labelStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade600),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            filled: true,
            fillColor: Colors.grey[900],
          ),
        ),
        const SizedBox(height: 16),

        // Event Type
        TextFormField(
          controller: _eventTypeController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Event Type (seminar, workshop, etc.)',
            labelStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade600),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            filled: true,
            fillColor: Colors.grey[900],
          ),
        ),
        const SizedBox(height: 16),

        // Is Audience
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade600),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedIsAudience,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              decoration: InputDecoration(
                labelText: 'Has Audience?',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: const [
                DropdownMenuItem(
                  value: '0',
                  child: Text('No', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text('Yes', style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedIsAudience = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Is Online
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade600),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedIsOnline,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              decoration: InputDecoration(
                labelText: 'Is Online Event?',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: const [
                DropdownMenuItem(
                  value: '0',
                  child: Text('No', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text('Yes', style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedIsOnline = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Status
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade600),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              style: const TextStyle(color: Colors.white),
              dropdownColor: Colors.grey[900],
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              decoration: InputDecoration(
                labelText: 'Status',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: const [
                DropdownMenuItem(
                  value: '0',
                  child:
                      Text('Inactive', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text('Active', style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value);
              },
            ),
          ),
        ),
      ],
    );
  }

// ================= STEP 4: MANAGE IMAGES =================
  Widget _buildStep4() {
    final totalImages = _existingImages.length + _selectedNewImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event Images',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Total: $totalImages/5 images',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (totalImages < 5)
              IconButton(
                onPressed: _addImageField,
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.blueAccent,
                  size: 30,
                ),
                tooltip: 'Add new image',
              ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          'Click eye icon to preview, edit icon to replace images',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        // Existing Images - Now in column (row-wise)
        if (_existingImages.isNotEmpty) ...[
          Text(
            'Existing Images',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Column में हर एक image को row-wise दिखाएं
          Column(
            children: List.generate(
              _existingImages.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildExistingImageItem(index),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // New Images Section
        if (_selectedNewImages.isNotEmpty) ...[
          Text(
            'New Images to Upload',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: List.generate(
              _selectedNewImages.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildNewImageField(index),
              ),
            ),
          ),
        ],

        // Add Image Button (when no images)
        if (_selectedNewImages.isEmpty && _existingImages.isEmpty)
          _buildAddImageButton(),
      ],
    );
  }

  // ================= BUILD EXISTING IMAGE ITEM =================

  Widget _buildExistingImageItem(int index) {
    final image = _existingImages[index];
    final imgPath = image['event_img_path'] ?? '';
    final imageUrl =
        '$_imageBaseUrl/$imgPath'.replaceAll(' ', '%20').replaceFirst('/', '');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image Preview - Fixed width
          Container(
            width: 100, // Fixed width for image
            height: 100, // Fixed height for image
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[800],
            ),
            child: GestureDetector(
              onTap: () => _showImagePreviewDialog(imageUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Image Details and Actions - Takes remaining space
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Image Info
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                //     Text(
                //       'Image ${index + 1}',
                //       style: TextStyle(
                //         color: Colors.white,
                //         fontSize: 14,
                //         fontWeight: FontWeight.w500,
                //       ),
                //     ),
                //     Container(
                //       padding: const EdgeInsets.symmetric(
                //         horizontal: 6,
                //         vertical: 2,
                //       ),
                //       decoration: BoxDecoration(
                //         color: Colors.grey[800],
                //         borderRadius: BorderRadius.circular(4),
                //       ),
                //       child: Text(
                //         'Existing',
                //         style: TextStyle(
                //           color: Colors.green,
                //           fontSize: 10,
                //           fontWeight: FontWeight.w500,
                //         ),
                //       ),
                //     ),
                //   ],
                // ),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Image ${index + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Existing',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Icon Buttons Row
                Container(
                  width: double.infinity, // Take full width
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Delete Icon Button
                      _buildIconButton(
                        icon: Icons.delete,
                        color: Colors.red,
                        tooltip: 'Delete Image',
                        onPressed: () => _removeExistingImage(index),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Helper method for Icon Button

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color, size: 18),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
        ),
      ),
    );
  }

  void _showImagePreviewDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            // Image Container
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: MediaQuery.of(context).size.height * 0.6,
                      placeholder: (context, url) => Container(
                        height: 300,
                        color: Colors.grey[800],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.blue,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 300,
                        color: Colors.grey[800],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 60,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Close Button
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),

                        // Copy URL Button
                        ElevatedButton(
                          onPressed: () {
                            // Copy URL logic
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('URL copied to clipboard'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.copy, size: 16),
                              SizedBox(width: 6),
                              Text('Copy URL'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Close Icon
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= REPLACE EXISTING IMAGE =================
  Future<void> _replaceExistingImage(int index) async {
    final XFile? selected =
        await _picker.pickImage(source: ImageSource.gallery);

    if (selected != null) {
      setState(() {
        // Add existing image to delete list
        final image = _existingImages[index];
        if (image['event_img_path'] != null) {
          _imagesToDelete.add(image['event_img_path']);
        }

        // Remove existing image
        _existingImages.removeAt(index);

        // Add new image at the same position
        _selectedNewImages.insert(index, selected);
      });
    }
  }

  // ================= BUILD NEW IMAGE FIELD =================
  Widget _buildNewImageField(int index) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Row(
            children: [
              // Image Preview or Placeholder
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => _pickNewImage(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedNewImages[index] != null
                            ? Colors.green
                            : Colors.blueAccent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedNewImages[index] != null
                              ? Icons.check_circle
                              : Icons.add_photo_alternate,
                          color: _selectedNewImages[index] != null
                              ? Colors.green
                              : Colors.blueAccent,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedNewImages[index] != null
                              ? 'New Image Selected'
                              : 'Choose Replacement',
                          style: TextStyle(
                            color: _selectedNewImages[index] != null
                                ? Colors.green
                                : Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedNewImages[index] != null)
                          const SizedBox(height: 4),
                        if (_selectedNewImages[index] != null)
                          Text(
                            'Will replace image ${index + 1}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Action Buttons
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // Edit/Change Button
                    IconButton(
                      onPressed: () => _pickNewImage(index),
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Change Image',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Delete Button
                    IconButton(
                      onPressed: () => _removeNewImageField(index),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Remove Image',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ================= BUILD ADD IMAGE BUTTON =================
  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _addImageField,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.blueAccent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_photo_alternate,
              color: Colors.blueAccent,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'Add Image',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= SHOW IMAGE URL DIALOG =================
  void _showImageUrlDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Image URL',
          style: TextStyle(color: Colors.white),
        ),
        content: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              imageUrl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: () {
              // Copy to clipboard functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('URL copied to clipboard'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy, color: Colors.blue),
            tooltip: 'Copy URL',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.blue,
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Event Data...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Event (Step ${_currentStep + 1}/4)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Progress Indicator
              LinearProgressIndicator(
                value: (_currentStep + 1) / 4,
                backgroundColor: Colors.grey[800],
                color: Colors.blue,
                minHeight: 4,
              ),
              const SizedBox(height: 16),

              // Stepper
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Colors.blue,
                    ),
                    canvasColor: Colors.black,
                  ),
                  child: Stepper(
                    currentStep: _currentStep,
                    onStepContinue: _nextStep,
                    onStepCancel: _previousStep,
                    onStepTapped: (step) {
                      if (step <= _currentStep) {
                        setState(() => _currentStep = step);
                      }
                    },
                    steps: _buildSteps(),
                    controlsBuilder: (context, details) {
                      return const SizedBox.shrink();
                    },
                    connectorColor: const MaterialStatePropertyAll(Colors.grey),
                  ),
                ),
              ),

              // Navigation Buttons
              Row(
                children: [
                  // Previous Button
                  if (_currentStep > 0)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _previousStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_back, size: 18),
                            SizedBox(width: 8),
                            Text('Previous', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),

                  if (_currentStep > 0) const SizedBox(width: 12),

                  // Next/Update Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _currentStep < 3
                              ? _nextStep
                              : _updateEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentStep < 3 ? 'Next' : 'Update Event',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_currentStep < 3) const SizedBox(width: 8),
                                if (_currentStep < 3)
                                  const Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IndustryModel {
  final int id;
  final String title;

  IndustryModel({required this.id, required this.title});

  factory IndustryModel.fromJson(Map<String, dynamic> json) {
    return IndustryModel(
      id: json['id'],
      title: json['title'] ?? '',
    );
  }
}

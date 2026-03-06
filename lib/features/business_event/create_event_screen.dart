import 'dart:convert';
// import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gridcard/config/app_config.dart';
import 'package:gridcard/core/services/user_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:gridcard/widgets/top_alert.dart';

class CreateEventScreen extends StatefulWidget {
  final VoidCallback onEventCreated;

  const CreateEventScreen({super.key, required this.onEventCreated});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  final List<XFile?> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  String? _selectedStateName;
  List<Map<String, dynamic>> _districts = []; // all districts
  List<Map<String, dynamic>> _filteredDistricts = []; // state wise

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
  String? _selectedIndustry;
  String? _selectedIndustryName;
  String? _selectedCountry;
  // String? _selectedState;
  int? _selectedState;
  String? _selectedDistrict;
  String? _selectedIsAudience;
  String? _selectedIsOnline;
  String? _selectedStatus;

  // Lists for dropdowns
  final List<Map<String, dynamic>> _industries = [];
  final List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];

  final bool _isIndustryLoading = false;

  // Validation Keys
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const String _baseUrl = AppConfig.apiBaseUrl;

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

  Future<void> _fetchIndustries() async {
    try {
      setState(() => isIndustryLoading = true);

      final uri = Uri.parse("$_baseUrl/industries");

      final response = await http.get(
        uri,
        headers: await _getHeaders(), // ✅ header pass
      );

      debugPrint("========== INDUSTRY API ==========");
      debugPrint("URL: $uri");
      debugPrint("STATUS: ${response.statusCode}");
      // debugPrint("BODY: ${response.body}");

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

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint("========== STATES API ==========");
      debugPrint("URL: $uri");
      debugPrint("STATUS: ${response.statusCode}");
      // debugPrint("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          final List list = jsonData["data"];

          // ✅ agar tum states list bhi store karna chahte ho
          setState(() {
            _states = list.map((e) {
              return {
                "id": e["id"],
                "state_name": e["state_name"],
                "c_id": e["c_id"],
              };
            }).toList();
          });

          // ✅ console me print
          debugPrint("TOTAL STATES: ${_states.length}");
          for (var s in _states) {
            debugPrint("State: ${s["id"]} - ${s["state_name"]}");
          }
        }
      }
    } catch (e) {
      debugPrint("States fetch error: $e");
    }
  }

  Future<void> _fetchDistricts() async {
    try {
      final uri = Uri.parse("$_baseUrl/districts");

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      );

      debugPrint("========== DISTRICTS API ==========");
      debugPrint("URL: $uri");
      debugPrint("STATUS: ${response.statusCode}");
      debugPrint("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          final List list = jsonData["data"];

          // setState(() {
          //   _districts = list.map((e) {
          //     return {
          //       "id": e["id"],
          //       "district_name": e["district_name"],
          //       "s_id": e["s_id"],
          //     };
          //   }).toList();
          // });

          setState(() {
            _districts = list.map((e) {
              return {
                "id": e["id"],
                "district_name": e["district_name"],
                "s_id": e["s_id"],
              };
            }).toList();

            _filteredDistricts = []; // initially empty
          });

          debugPrint("TOTAL DISTRICTS: ${_districts.length}");
          for (var d in _districts) {
            debugPrint(
                "District: ${d["id"]} - ${d["district_name"]} (State ID: ${d["s_id"]})");
          }
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
    _fetchIndustries();
    _fetchStates();
    _fetchDistricts();
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
      // case 1:
      //   if (_selectedIndustry == null) {
      //     _showError('Please select industry');
      //     return false;
      //   }
      //   return true;
      case 1:
        if (selectedIndustryId == null) {
          _showError('Please select industry');
          return false;
        }
        return true;
      case 2:
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    TopAlert.show(context, message, isError: true);
  }

  void _showSuccess(String message) {
    TopAlert.show(context, message, isSuccess: true);
  }

  // ================= IMAGE PICKER =================
  Future<void> _pickImage(int index) async {
    final XFile? selected =
        await _picker.pickImage(source: ImageSource.gallery);
    if (selected != null) {
      setState(() {
        if (_selectedImages.length > index) {
          _selectedImages[index] = selected;
        } else {
          _selectedImages.add(selected);
        }
      });
    }
  }

  void _addImageField() {
    if (_selectedImages.length < 5) {
      setState(() {
        _selectedImages.add(null);
      });
    } else {
      TopAlert.show(context, 'Maximum 5 images allowed', isError: true);
    }
  }

  void _removeImageField(int index) {
    setState(() {
      _selectedImages.removeAt(index);
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

  // ================= CREATE EVENT API =================

  Future<void> _createEvent() async {
    if (!_validateCurrentStep()) return;

    final validImages = _selectedImages.where((img) => img != null).toList();

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse("$_baseUrl/create-event");
      final request = http.MultipartRequest("POST", uri);

      // headers
      request.headers.addAll(await _getHeadersMultipart());

      // fields
      request.fields['title'] = _titleController.text.trim();
      request.fields['description'] = _descriptionController.text.trim();
      request.fields['start_date'] = _startDateController.text.trim();

      if (_descriptionController.text.trim().isNotEmpty) {
        request.fields['description'] = _descriptionController.text.trim();
      }

      if (_linkController.text.trim().isNotEmpty) {
        request.fields['link'] = _linkController.text.trim();
      }

      // if (_selectedIndustry != null) {
      //   request.fields['indus_type'] = _selectedIndustry!;
      // }
      if (selectedIndustryId != null) {
        request.fields['indus_type'] = selectedIndustryId.toString();
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

      // if (_selectedState != null) {
      //   request.fields['state_id'] = _selectedState!;
      // }

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

      // images (IMPORTANT FIX FOR WEB)
      for (int i = 0; i < validImages.length; i++) {
        final img = validImages[i]!;

        final bytes = await img.readAsBytes(); // ✅ works in Android + iOS + Web

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

      debugPrint("========== CREATE EVENT API ==========");
      debugPrint("STATUS CODE: ${response.statusCode}");
      debugPrint("RESPONSE: $jsonResponse");

      if (response.statusCode == 200 && jsonResponse['status'] == true) {
        _showSuccess(jsonResponse['message'] ?? "Event created successfully!");
        widget.onEventCreated();
        Navigator.pop(context);
      } else {
        _showError(jsonResponse['message'] ?? "Failed to create event");
      }
    } catch (e) {
      debugPrint("EXCEPTION: $e");
      _showError("Error creating event: $e");
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
            const Text('Upload Images', style: TextStyle(color: Colors.white)),
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
              initialValue: selectedIndustryId,
              isExpanded: true, // ✅ ADD THIS
              dropdownColor: Colors.grey[900],
              decoration: InputDecoration(
                labelText: "Industry Type",
                labelStyle: const TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16), // optional
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
                debugPrint("Selected Industry ID: $selectedIndustryId");
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Country
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade600),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedCountry,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              decoration: InputDecoration(
                labelText: 'Country',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: _countries.isEmpty
                  ? [
                      const DropdownMenuItem(
                        value: '1',
                        child: Text('India',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ]
                  : _countries.map((country) {
                      return DropdownMenuItem(
                        value: country['id'].toString(),
                        child: Text(country['ctry_name'],
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCountry = value;
                  _selectedState = null;
                  _selectedDistrict = null;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<int>(
              initialValue: _selectedState,
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

                  // ✅ Filter districts based on state id
                  _filteredDistricts =
                      _districts.where((d) => d["s_id"] == value).toList();
                });

                debugPrint("Selected State ID: $_selectedState");
                debugPrint("Filtered Districts: ${_filteredDistricts.length}");
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
              initialValue: _selectedDistrict,
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
              initialValue: _selectedIsAudience,
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
              initialValue: _selectedIsOnline,
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
              initialValue: _selectedStatus,
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

  // ================= BUILD IMAGE FIELD =================
  Widget _buildImageField(int index) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickImage(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedImages[index] != null
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
                          _selectedImages[index] != null
                              ? Icons.check_circle
                              : Icons.add_photo_alternate,
                          color: _selectedImages[index] != null
                              ? Colors.green
                              : Colors.blueAccent,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedImages[index] != null
                              ? 'Image Selected'
                              : 'Choose Image',
                          style: TextStyle(
                            color: _selectedImages[index] != null
                                ? Colors.green
                                : Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _removeImageField(index),
                icon: const Icon(Icons.delete, color: Colors.red),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= STEP 4: UPLOAD IMAGES =================
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Event Images (Max: 5)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_selectedImages.length < 5)
              IconButton(
                onPressed: _addImageField,
                icon: const Icon(
                  Icons.add_circle,
                  color: Colors.blueAccent,
                  size: 30,
                ),
                tooltip: 'Add image field',
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Supported formats: JPG, JPEG, PNG, WEBP\nMax size: 10MB per image',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        // Image Fields
        if (_selectedImages.isEmpty)
          Column(
            children: [
              const SizedBox(height: 12),
              GestureDetector(
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
              ),
            ],
          )
        else
          Column(
            children: List.generate(
              _selectedImages.length,
              (index) => _buildImageField(index),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Create Event (Step ${_currentStep + 1}/4)',
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
                    connectorColor: const WidgetStatePropertyAll(Colors.grey),
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

                  // Next/Submit Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _currentStep < 3
                              ? _nextStep
                              : _createEvent,
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
                                  _currentStep < 3 ? 'Next' : 'Submit',
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

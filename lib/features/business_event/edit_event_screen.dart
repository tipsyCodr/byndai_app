import 'dart:convert';
import 'dart:typed_data';
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
import 'package:gridcard/widgets/top_alert.dart';

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

  final bool _isIndustryLoading = false;

  // Validation Keys
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const String _imageBaseUrl = AppConfig.imageBaseUrl;
  static const String _storageBaseUrl = 'https://app.byndai.in/storage';

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

    debugPrint("========== INITIALIZING FORM DATA ==========");
    debugPrint("Event Data: $event");

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
        // Validate that we have at least one image if no existing images and no new images selected
        final hasImages = _existingImages.isNotEmpty ||
            _selectedNewImages.where((img) => img != null).isNotEmpty;
        if (!hasImages) {
          _showError('Please add at least one image for the event');
          return false;
        }
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

  // ================= IMAGE MANAGEMENT =================
  // Future<void> _pickNewImage(int index) async {
  //   final XFile? selected =
  //       await _picker.pickImage(source: ImageSource.gallery);
  //   if (selected != null) {
  //     setState(() {
  //       if (_selectedNewImages.length > index) {
  //         _selectedNewImages[index] = selected;
  //       } else {
  //         _selectedNewImages.add(selected);
  //       }
  //     });
  //   }
  // }

  // ================= IMAGE MANAGEMENT =================
  Future<void> _pickNewImage(int index) async {
    try {
      final XFile? selected =
          await _picker.pickImage(source: ImageSource.gallery);

      if (selected != null) {
        // Web के लिए bytes read करें और store करें
        if (kIsWeb) {
          final bytes = await selected.readAsBytes();
          setState(() {
            if (_selectedNewImages.length > index) {
              _selectedNewImages[index] = selected;
            } else {
              _selectedNewImages.add(selected);
            }
          });
        } else {
          // Mobile के लिए direct file use करें
          setState(() {
            if (_selectedNewImages.length > index) {
              _selectedNewImages[index] = selected;
            } else {
              _selectedNewImages.add(selected);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      _showError("Failed to pick image: ${e.toString()}");
    }
  }

  void _addImageField() {
    if (_existingImages.length + _selectedNewImages.length < 5) {
      setState(() {
        _selectedNewImages.add(null);
      });
    } else {
      TopAlert.show(context, 'Maximum 5 images allowed', isError: true);
    }
  }

  void _removeExistingImage(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Image'),
          content: const Text('Are you sure you want to delete this image?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                final image = _existingImages[index];
                if (image['event_img_path'] != null) {
                  _imagesToDelete.add(image['event_img_path']);
                }
                setState(() {
                  _existingImages.removeAt(index);
                });
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
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
      builder: (context, child) {
        final colorScheme = Theme.of(context).colorScheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
              surface: colorScheme.surface,
              onSurface: colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      if (isStartDate) {
        _startDateController.text = formattedDate;

        // Validate end date if it's before start date
        if (_endDateController.text.isNotEmpty) {
          final endDate = DateTime.parse(_endDateController.text);
          if (endDate.isBefore(picked)) {
            _endDateController.clear();
            _showError('End date cannot be before start date');
          }
        }
      } else {
        // Validate end date is after start date
        if (_startDateController.text.isNotEmpty) {
          final startDate = DateTime.parse(_startDateController.text);
          if (picked.isBefore(startDate)) {
            _showError('End date cannot be before start date');
            return;
          }
        }
        _endDateController.text = formattedDate;
      }
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        final colorScheme = Theme.of(context).colorScheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
              surface: colorScheme.surface,
              onSurface: colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      _timingController.text = '$hour:$minute:00';
    }
  }

  // ================= UPDATE EVENT API =================
  // Future<void> _updateEvent() async {
  //   if (!_validateCurrentStep()) return;

  //   final validNewImages =
  //       _selectedNewImages.where((img) => img != null).toList();

  //   setState(() => _isLoading = true);

  //   try {
  //     final uri = Uri.parse("$_baseUrl/update-event/${widget.eventData['id']}");
  //     final request = http.MultipartRequest("POST", uri);

  //     // headers
  //     request.headers.addAll(await _getHeadersMultipart());

  //     // Add all fields
  //     Map<String, String> fields = {
  //       'title': _titleController.text.trim(),
  //       'description': _descriptionController.text.trim(),
  //       'start_date': _startDateController.text.trim(),
  //     };

  //     // Add optional fields if they have values
  //     if (selectedIndustryId != null) {
  //       fields['indus_type'] = selectedIndustryId.toString();
  //     }

  //     if (_linkController.text.trim().isNotEmpty) {
  //       fields['link'] = _linkController.text.trim();
  //     }

  //     if (_endDateController.text.trim().isNotEmpty) {
  //       fields['end_date'] = _endDateController.text.trim();
  //     }

  //     if (_timingController.text.trim().isNotEmpty) {
  //       fields['timing'] = _timingController.text.trim();
  //     }

  //     if (_selectedCountry != null) {
  //       fields['country_id'] = _selectedCountry!;
  //     }

  //     if (_selectedState != null) {
  //       fields['state_id'] = _selectedState.toString();
  //     }

  //     if (_selectedDistrict != null) {
  //       fields['district_id'] = _selectedDistrict!;
  //     }

  //     if (_locationController.text.trim().isNotEmpty) {
  //       fields['location'] = _locationController.text.trim();
  //     }

  //     if (_eventTypeController.text.trim().isNotEmpty) {
  //       fields['event_type'] = _eventTypeController.text.trim();
  //     }

  //     if (_maxAttendeesController.text.trim().isNotEmpty) {
  //       fields['max_attendees'] = _maxAttendeesController.text.trim();
  //     }

  //     if (_selectedIsAudience != null) {
  //       fields['is_audience'] = _selectedIsAudience!;
  //     }

  //     if (_selectedIsOnline != null) {
  //       fields['is_online'] = _selectedIsOnline!;
  //     }

  //     if (_selectedStatus != null) {
  //       fields['status'] = _selectedStatus!;
  //     }

  //     // Add all fields to request
  //     request.fields.addAll(fields);

  //     // Add images to delete - IMPORTANT: Send as array
  //     for (var imgPath in _imagesToDelete) {
  //       request.fields['delete_images[]'] = imgPath;
  //     }

  //     // Add new images
  //     for (int i = 0; i < validNewImages.length; i++) {
  //       final img = validNewImages[i]!;
  //       final bytes = await img.readAsBytes();
  //       final fileExtension = img.path.split('.').last.toLowerCase();

  //       MediaType contentType;
  //       if (fileExtension == 'png') {
  //         contentType = MediaType("image", "png");
  //       } else if (fileExtension == 'webp') {
  //         contentType = MediaType("image", "webp");
  //       } else {
  //         contentType = MediaType("image", "jpeg");
  //       }

  //       request.files.add(
  //         http.MultipartFile.fromBytes(
  //           "event_img[]",
  //           bytes,
  //           filename: img.name,
  //           contentType: contentType,
  //         ),
  //       );
  //     }

  //     debugPrint("========== UPDATE EVENT API REQUEST ==========");
  //     debugPrint("URL: $uri");
  //     debugPrint("FIELDS: ${request.fields}");
  //     debugPrint("IMAGES TO DELETE: $_imagesToDelete");
  //     debugPrint("NEW IMAGES COUNT: ${validNewImages.length}");

  //     final response = await request.send();
  //     final responseBody = await response.stream.bytesToString();

  //     debugPrint("========== UPDATE EVENT API RESPONSE ==========");
  //     debugPrint("STATUS CODE: ${response.statusCode}");
  //     debugPrint("RESPONSE BODY: $responseBody");

  //     // Try to parse response
  //     Map<String, dynamic> jsonResponse;
  //     try {
  //       jsonResponse = json.decode(responseBody);
  //     } catch (e) {
  //       debugPrint("Error parsing response: $e");
  //       _showError("Server returned invalid response");
  //       setState(() => _isLoading = false);
  //       return;
  //     }

  //     if (response.statusCode == 200 && jsonResponse['status'] == true) {
  //       _showSuccess(jsonResponse['message'] ?? "Event updated successfully!");
  //       widget.onEventUpdated();
  //       Navigator.pop(context);
  //     } else {
  //       String errorMessage =
  //           jsonResponse['message'] ?? "Failed to update event";
  //       if (jsonResponse['errors'] != null) {
  //         final errors = jsonResponse['errors'] as Map;
  //         errorMessage = errors.values.first.first.toString();
  //       }
  //       _showError(errorMessage);
  //     }
  //   } catch (e) {
  //     debugPrint("EXCEPTION: $e");
  //     _showError("Error updating event: ${e.toString()}");
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

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

    // Add all fields
    Map<String, String> fields = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'start_date': _startDateController.text.trim(),
    };

    // Add optional fields if they have values
    if (selectedIndustryId != null) {
      fields['indus_type'] = selectedIndustryId.toString();
    }

    if (_linkController.text.trim().isNotEmpty) {
      fields['link'] = _linkController.text.trim();
    }

    if (_endDateController.text.trim().isNotEmpty) {
      fields['end_date'] = _endDateController.text.trim();
    }

    if (_timingController.text.trim().isNotEmpty) {
      fields['timing'] = _timingController.text.trim();
    }

    if (_selectedCountry != null) {
      fields['country_id'] = _selectedCountry!;
    }

    if (_selectedState != null) {
      fields['state_id'] = _selectedState.toString();
    }

    if (_selectedDistrict != null) {
      fields['district_id'] = _selectedDistrict!;
    }

    if (_locationController.text.trim().isNotEmpty) {
      fields['location'] = _locationController.text.trim();
    }

    if (_eventTypeController.text.trim().isNotEmpty) {
      fields['event_type'] = _eventTypeController.text.trim();
    }

    if (_maxAttendeesController.text.trim().isNotEmpty) {
      fields['max_attendees'] = _maxAttendeesController.text.trim();
    }

    if (_selectedIsAudience != null) {
      fields['is_audience'] = _selectedIsAudience!;
    }

    if (_selectedIsOnline != null) {
      fields['is_online'] = _selectedIsOnline!;
    }

    if (_selectedStatus != null) {
      fields['status'] = _selectedStatus!;
    }

    // Add all fields to request
    request.fields.addAll(fields);

    // Add images to delete - IMPORTANT: Send as array
    for (var imgPath in _imagesToDelete) {
      request.fields['delete_images[]'] = imgPath;
    }

    // Add new images - Web और Mobile दोनों के लिए bytes से upload करें
    for (int i = 0; i < validNewImages.length; i++) {
      final img = validNewImages[i]!;
      
      try {
        final bytes = await img.readAsBytes();
        final fileExtension = img.name.split('.').last.toLowerCase();

        MediaType contentType;
        if (fileExtension == 'png') {
          contentType = MediaType("image", "png");
        } else if (fileExtension == 'webp') {
          contentType = MediaType("image", "webp");
        } else {
          contentType = MediaType("image", "jpeg");
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            "event_img[]",
            bytes,
            filename: img.name,
            contentType: contentType,
          ),
        );
        
        debugPrint("Added image ${i+1}: ${img.name}, size: ${bytes.length} bytes");
      } catch (e) {
        debugPrint("Error processing image ${img.name}: $e");
        _showError("Error processing image: ${img.name}");
        setState(() => _isLoading = false);
        return;
      }
    }

    debugPrint("========== UPDATE EVENT API REQUEST ==========");
    debugPrint("URL: $uri");
    debugPrint("FIELDS: ${request.fields}");
    debugPrint("IMAGES TO DELETE: $_imagesToDelete");
    debugPrint("NEW IMAGES COUNT: ${validNewImages.length}");

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    debugPrint("========== UPDATE EVENT API RESPONSE ==========");
    debugPrint("STATUS CODE: ${response.statusCode}");
    debugPrint("RESPONSE BODY: ${response.body}");

    // Try to parse response
    Map<String, dynamic> jsonResponse;
    try {
      jsonResponse = json.decode(response.body);
    } catch (e) {
      debugPrint("Error parsing response: $e");
      debugPrint("Raw response: ${response.body}");
      _showError("Server returned invalid response");
      setState(() => _isLoading = false);
      return;
    }

    if (response.statusCode == 200 && jsonResponse['status'] == true) {
      _showSuccess(jsonResponse['message'] ?? "Event updated successfully!");
      widget.onEventUpdated();
      Navigator.pop(context);
    } else {
      String errorMessage =
          jsonResponse['message'] ?? "Failed to update event";
      if (jsonResponse['errors'] != null) {
        final errors = jsonResponse['errors'] as Map;
        errorMessage = errors.values.first.first.toString();
      }
      _showError(errorMessage);
    }
  } catch (e) {
    debugPrint("EXCEPTION: $e");
    debugPrint("Stack trace: ${StackTrace.current}");
    _showError("Error updating event: ${e.toString()}");
  } finally {
    setState(() => _isLoading = false);
  }
}

  // ================= FETCH UPDATED EVENT DATA =================
  Future<Map<String, dynamic>?> _fetchUpdatedEvent() async {
    try {
      final uri = Uri.parse("$_baseUrl/event/${widget.eventData['id']}");
      final response = await http.get(uri, headers: await _getHeaders());

      debugPrint("========== FETCH UPDATED EVENT ==========");
      debugPrint("URL: $uri");
      debugPrint("STATUS: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == true) {
          return jsonResponse['data'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching updated event: $e");
    }
    return null;
  }

  // ================= BUILD STEPPER =================
  List<Step> _buildSteps() {
    final colorScheme = Theme.of(context).colorScheme;

    return [
      Step(
        title:
            Text('Basic Info', style: TextStyle(color: colorScheme.onSurface)),
        content: _buildStep1(),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('Location & Timing',
            style: TextStyle(color: colorScheme.onSurface)),
        content: _buildStep2(),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('Event Details',
            style: TextStyle(color: colorScheme.onSurface)),
        content: _buildStep3(),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: Text('Manage Images',
            style: TextStyle(color: colorScheme.onSurface)),
        content: _buildStep4(),
        isActive: _currentStep >= 3,
        state: StepState.indexed,
      ),
    ];
  }

  // ================= STEP 1: BASIC INFO =================
  Widget _buildStep1() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Title
          TextFormField(
            controller: _titleController,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Event Title *',
              labelStyle:
                  TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: colorScheme.primary.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: colorScheme.primary.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
              filled: true,
              fillColor: isDark
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.1),
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
            style: TextStyle(color: colorScheme.onSurface),
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Description',
              labelStyle:
                  TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: colorScheme.primary.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: colorScheme.primary.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
              filled: true,
              fillColor: isDark
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 16),

          // Link
          TextFormField(
            controller: _linkController,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Event Link (URL)',
              labelStyle:
                  TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: colorScheme.primary.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: colorScheme.primary.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
              filled: true,
              fillColor: isDark
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 16),

          // Start Date
          TextFormField(
            controller: _startDateController,
            style: TextStyle(color: colorScheme.onSurface),
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Start Date *',
              labelStyle:
                  TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: colorScheme.primary.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: colorScheme.primary.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
              filled: true,
              fillColor: isDark
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.1),
              suffixIcon: IconButton(
                icon: Icon(Icons.calendar_today,
                    color: colorScheme.onSurface.withOpacity(0.6)),
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
            style: TextStyle(color: colorScheme.onSurface),
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'End Date (Optional)',
              labelStyle:
                  TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: colorScheme.primary.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: colorScheme.primary.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
              filled: true,
              fillColor: isDark
                  ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.1),
              suffixIcon: IconButton(
                icon: Icon(Icons.calendar_today,
                    color: colorScheme.onSurface.withOpacity(0.6)),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Timing
        TextFormField(
          controller: _timingController,
          style: TextStyle(color: colorScheme.onSurface),
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Event Timing (Optional)',
            labelStyle:
                TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: colorScheme.primary.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: colorScheme.primary.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: isDark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.1),
            suffixIcon: IconButton(
              icon: Icon(Icons.access_time,
                  color: colorScheme.onSurface.withOpacity(0.6)),
              onPressed: _selectTime,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Industry Type Dropdown
        isIndustryLoading
            ? const Center(child: CircularProgressIndicator())
            : Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                      : colorScheme.surfaceContainerHighest.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: colorScheme.primary.withOpacity(0.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<int>(
                    value: selectedIndustryId,
                    isExpanded: true,
                    dropdownColor: isDark
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.surface,
                    decoration: InputDecoration(
                      labelText: "Industry Type *",
                      labelStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    items: industries.isEmpty
                        ? [
                            DropdownMenuItem<int>(
                              value: null,
                              child: Text(
                                'No industries available',
                                style: TextStyle(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.5)),
                              ),
                            )
                          ]
                        : industries.map((industry) {
                            return DropdownMenuItem<int>(
                              value: industry.id,
                              child: Text(
                                industry.title,
                                style: TextStyle(color: colorScheme.onSurface),
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
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<int>(
              value: _selectedState,
              isExpanded: true,
              dropdownColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surface,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
              icon: Icon(Icons.keyboard_arrow_down,
                  color: colorScheme.onSurface.withOpacity(0.6)),
              decoration: InputDecoration(
                labelText: "State",
                labelStyle: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 13),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: _states.isEmpty
                  ? [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          'No states available',
                          style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.5)),
                        ),
                      )
                    ]
                  : _states.map((state) {
                      return DropdownMenuItem<int>(
                        value: state['id'],
                        child: Text(
                          state['state_name'],
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      );
                    }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedState = value;
                  _selectedStateName = _states.firstWhere(
                      (state) => state['id'] == value)['state_name'];
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
            color: isDark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedDistrict,
              isExpanded: true,
              dropdownColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surface,
              style: TextStyle(color: colorScheme.onSurface),
              icon: Icon(Icons.arrow_drop_down,
                  color: colorScheme.onSurface.withOpacity(0.6)),
              decoration: InputDecoration(
                labelText: 'District',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: _filteredDistricts.isEmpty
                  ? [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          _selectedState == null
                              ? 'Select state first'
                              : 'No districts available',
                          style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.5)),
                        ),
                      )
                    ]
                  : _filteredDistricts.map((district) {
                      return DropdownMenuItem(
                        value: district['id'].toString(),
                        child: Text(
                          district['district_name'],
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      );
                    }).toList(),
              onChanged: (_selectedState == null || _filteredDistricts.isEmpty)
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
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: 'Location/Venue',
            labelStyle:
                TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: colorScheme.primary.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: colorScheme.primary.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: isDark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  // ================= STEP 3: EVENT DETAILS =================
  Widget _buildStep3() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Max Attendees
        TextFormField(
          controller: _maxAttendeesController,
          style: TextStyle(color: colorScheme.onSurface),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Max Attendees',
            labelStyle:
                TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: colorScheme.primary.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: colorScheme.primary.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: isDark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.1),
          ),
        ),
        const SizedBox(height: 16),

        // Event Type
        TextFormField(
          controller: _eventTypeController,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: 'Event Type (seminar, workshop, etc.)',
            labelStyle:
                TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: colorScheme.primary.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: colorScheme.primary.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: isDark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.1),
          ),
        ),
        const SizedBox(height: 16),

        // Is Audience
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedIsAudience,
              isExpanded: true,
              dropdownColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surface,
              style: TextStyle(color: colorScheme.onSurface),
              icon: Icon(Icons.arrow_drop_down,
                  color: colorScheme.onSurface.withOpacity(0.6)),
              decoration: InputDecoration(
                labelText: 'Is this a Private Event?',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: const [
                DropdownMenuItem(
                  value: '0',
                  child: Text('No'),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text('Yes'),
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
            color: isDark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedIsOnline,
              isExpanded: true,
              dropdownColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surface,
              style: TextStyle(color: colorScheme.onSurface),
              icon: Icon(Icons.arrow_drop_down,
                  color: colorScheme.onSurface.withOpacity(0.6)),
              decoration: InputDecoration(
                labelText: 'Is Online Event?',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: const [
                DropdownMenuItem(
                  value: '0',
                  child: Text('No'),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text('Yes'),
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
            color: isDark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              isExpanded: true,
              style: TextStyle(color: colorScheme.onSurface),
              dropdownColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surface,
              icon: Icon(Icons.arrow_drop_down,
                  color: colorScheme.onSurface.withOpacity(0.6)),
              decoration: InputDecoration(
                labelText: 'Status',
                labelStyle:
                    TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: const [
                DropdownMenuItem(
                  value: '0',
                  child: Text('Inactive'),
                ),
                DropdownMenuItem(
                  value: '1',
                  child: Text('Active'),
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
    final colorScheme = Theme.of(context).colorScheme;
    final totalImages = _existingImages.length + _selectedNewImages.length;
    final validNewImagesCount =
        _selectedNewImages.where((img) => img != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event Images',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: $totalImages/5 images (${validNewImagesCount} new)',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (totalImages < 5)
                    ElevatedButton.icon(
                      onPressed: _addImageField,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: totalImages / 5,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                color: totalImages == 5 ? Colors.red : colorScheme.primary,
                minHeight: 4,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Info Text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Click on image to preview. Use delete button to remove existing images. Add new images to upload.',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Existing Images
        if (_existingImages.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Existing Images (${_existingImages.length})',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            _existingImages.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildExistingImageItem(index),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // New Images Section
        if (_selectedNewImages.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'New Images to Upload (${_selectedNewImages.length})',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            _selectedNewImages.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildNewImageField(index),
            ),
          ),
        ],

        // Empty State
        if (_existingImages.isEmpty && _selectedNewImages.isEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                    style: BorderStyle.none),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 64,
                    color: colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No images added yet',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addImageField,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add First Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ================= BUILD EXISTING IMAGE ITEM =================
  Widget _buildExistingImageItem(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final image = _existingImages[index];
    final fullUrl = image['full_url']?.toString();
    final imgPath = image['event_img_path']?.toString() ?? '';
    final imageUrl = (fullUrl != null && fullUrl.trim().isNotEmpty)
        ? fullUrl.trim().replaceAll(' ', '%20')
        : (_buildEventStorageUrl(imgPath) ??
            AppConfig.getFullUrl(imgPath) ??
            '$_imageBaseUrl/$imgPath').replaceAll(' ', '%20');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview
            GestureDetector(
              onTap: () => _showImagePreviewDialog(imageUrl),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: colorScheme.primary.withOpacity(0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color:
                          colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: colorScheme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color:
                          colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: colorScheme.onSurface.withOpacity(0.3),
                            size: 30,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Error',
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Image Details and Actions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Image ${index + 1}',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Existing',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    image['event_img'] ?? '',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildIconButton(
                        icon: Icons.visibility,
                        color: colorScheme.primary,
                        tooltip: 'Preview',
                        onPressed: () => _showImagePreviewDialog(imageUrl),
                      ),
                      const SizedBox(width: 8),
                      _buildIconButton(
                        icon: Icons.delete,
                        color: colorScheme.error,
                        tooltip: 'Delete Image',
                        onPressed: () => _removeExistingImage(index),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _buildEventStorageUrl(String rawPath) {
    String path = rawPath.trim();
    if (path.isEmpty) return null;

    if (path.startsWith('http')) {
      return path.replaceAll(' ', '%20');
    }

    path = path.replaceAll('\\', '/');
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    if (path.startsWith('event/')) {
      return '$_storageBaseUrl/$path'.replaceAll(' ', '%20');
    }

    final filename = path.split('/').last;
    final eventName = (_titleController.text.isNotEmpty
            ? _titleController.text
            : (widget.eventData['event_name'] ?? widget.eventData['title'] ?? 'event')
                .toString())
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return '$_storageBaseUrl/event/$eventName/$filename'.replaceAll(' ', '%20');
  }

  // Helper method for Icon Button
  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color, size: 20),
          constraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  void _showImagePreviewDialog(String imageUrl) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.image, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Image Preview',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),

                  // Image
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: ClipRRect(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          height: 300,
                          color: colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colorScheme.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 300,
                          color: colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: colorScheme.onSurface.withOpacity(0.3),
                                  size: 60,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.surfaceContainerHighest.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            // Copy URL functionality
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy URL'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= BUILD NEW IMAGE FIELD =================
  // Widget _buildNewImageField(int index) {
  //   final colorScheme = Theme.of(context).colorScheme;
  //   final isDark = Theme.of(context).brightness == Brightness.dark;
  //   final hasImage = _selectedNewImages[index] != null;

  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     child: Container(
  //       padding: const EdgeInsets.all(12),
  //       decoration: BoxDecoration(
  //         color: isDark
  //             ? colorScheme.surfaceContainerHighest
  //             : colorScheme.surface,
  //         borderRadius: BorderRadius.circular(12),
  //         border: hasImage ? Border.all(color: Colors.green, width: 1) : null,
  //       ),
  //       child: Row(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           // Image Preview or Placeholder
  //           Expanded(
  //             flex: 2,
  //             child: GestureDetector(
  //               onTap: () => _pickNewImage(index),
  //               child: Container(
  //                 height: 120,
  //                 decoration: BoxDecoration(
  //                   color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
  //                   borderRadius: BorderRadius.circular(8),
  //                   border: Border.all(
  //                     color: hasImage ? Colors.green : colorScheme.primary,
  //                     width: 2,
  //                   ),
  //                 ),
  //                 // child: hasImage
  //                 //     ? ClipRRect(
  //                 //         borderRadius: BorderRadius.circular(8),
  //                 //         child: Image.file(
  //                 //           File(_selectedNewImages[index]!.path),
  //                 //           fit: BoxFit.cover,
  //                 //         ),
  //                 //       )
  //                 //     : Column(
  //                 //         mainAxisAlignment: MainAxisAlignment.center,
  //                 //         children: [
  //                 //           Icon(
  //                 //             Icons.add_photo_alternate,
  //                 //             color: colorScheme.primary,
  //                 //             size: 32,
  //                 //           ),
  //                 //           const SizedBox(height: 8),
  //                 //           Text(
  //                 //             'Tap to select image',
  //                 //             style: TextStyle(
  //                 //               color: colorScheme.primary,
  //                 //               fontSize: 12,
  //                 //               fontWeight: FontWeight.w500,
  //                 //             ),
  //                 //           ),
  //                 //         ],
  //                 //       ),

  //                 child: hasImage
  //                     ? ClipRRect(
  //                         borderRadius: BorderRadius.circular(8),
  //                         child: FutureBuilder<Uint8List>(
  //                           future: _selectedNewImages[index]!.readAsBytes(),
  //                           builder: (context, snapshot) {
  //                             if (!snapshot.hasData) {
  //                               return const Center(
  //                                 child: CircularProgressIndicator(),
  //                               );
  //                             }

  //                             return Image.memory(
  //                               snapshot.data!,
  //                               fit: BoxFit.cover,
  //                             );
  //                           },
  //                         ),
  //                       )
  //                     : Column(
  //                         mainAxisAlignment: MainAxisAlignment.center,
  //                         children: [
  //                           Icon(
  //                             Icons.add_photo_alternate,
  //                             color: colorScheme.primary,
  //                             size: 32,
  //                           ),
  //                           const SizedBox(height: 8),
  //                           Text(
  //                             'Tap to select image',
  //                             style: TextStyle(
  //                               color: colorScheme.primary,
  //                               fontSize: 12,
  //                               fontWeight: FontWeight.w500,
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //               ),
  //             ),
  //           ),

  //           const SizedBox(width: 12),

  //           // Action Buttons
  //           Expanded(
  //             flex: 1,
  //             child: Column(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 if (hasImage)
  //                   Container(
  //                     padding: const EdgeInsets.symmetric(
  //                         horizontal: 8, vertical: 4),
  //                     decoration: BoxDecoration(
  //                       color: Colors.green.withOpacity(0.1),
  //                       borderRadius: BorderRadius.circular(12),
  //                     ),
  //                     child: Text(
  //                       'Selected',
  //                       style: TextStyle(
  //                         color: Colors.green.shade700,
  //                         fontSize: 10,
  //                         fontWeight: FontWeight.w500,
  //                       ),
  //                     ),
  //                   ),
  //                 const SizedBox(height: 12),
  //                 _buildIconButton(
  //                   icon: Icons.edit,
  //                   color: colorScheme.primary,
  //                   tooltip: 'Change Image',
  //                   onPressed: () => _pickNewImage(index),
  //                 ),
  //                 const SizedBox(height: 8),
  //                 _buildIconButton(
  //                   icon: Icons.delete,
  //                   color: colorScheme.error,
  //                   tooltip: 'Remove',
  //                   onPressed: () => _removeNewImageField(index),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // ================= BUILD NEW IMAGE FIELD =================
  Widget _buildNewImageField(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = _selectedNewImages[index] != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: hasImage ? Border.all(color: Colors.green, width: 1) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview or Placeholder
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => _pickNewImage(index),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasImage ? Colors.green : colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: hasImage
                      ? FutureBuilder<Uint8List>(
                          future: _selectedNewImages[index]!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError || !snapshot.hasData) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: colorScheme.error,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Error loading image',
                                      style: TextStyle(
                                        color: colorScheme.error,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          color: colorScheme.error,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Broken image',
                                          style: TextStyle(
                                            color: colorScheme.error,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              color: colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to select image',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasImage)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Selected',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _buildIconButton(
                    icon: Icons.edit,
                    color: colorScheme.primary,
                    tooltip: 'Change Image',
                    onPressed: () => _pickNewImage(index),
                  ),
                  const SizedBox(height: 8),
                  _buildIconButton(
                    icon: Icons.delete,
                    color: colorScheme.error,
                    tooltip: 'Remove',
                    onPressed: () => _removeNewImageField(index),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 1,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Edit Event',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: colorScheme.primary,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Event Data...',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Event',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of 4',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${((_currentStep + 1) * 25).toInt()}% Complete',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / 4,
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    color: colorScheme.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),

            // Stepper Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildSteps()[_currentStep].content,
              ),
            ),

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Previous Button
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.onSurface,
                          side: BorderSide(
                              color: colorScheme.primary.withOpacity(0.3)),
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
                            Text('Previous'),
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
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentStep < 3 ? 'Next' : 'Update Event',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_currentStep < 3) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 18),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

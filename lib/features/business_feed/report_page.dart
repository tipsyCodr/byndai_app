import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:gridcard/core/services/user_storage_service.dart';

class ReportPage extends StatefulWidget {
  final int postId;

  const ReportPage({
    super.key,
    required this.postId,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  static const String _baseUrl =
      "https://powderblue-jellyfish-554082.hostingersite.com/api";

  // =========================
  // STATE VARIABLES
  // =========================
  int _currentStep = 0; // 0: Reason selection, 1: Message, 2: Success
  String? _selectedReason;
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;

  // =========================
  // REPORT REASONS LIST
  // =========================
  final List<Map<String, String>> _reportReasons = [
    {"value": "sexual_content", "label": "Sexual content"},
    {"value": "violent_content", "label": "Violent or repulsive content"},
    {"value": "hateful_content", "label": "Hateful or abusive content"},
    {"value": "harassment", "label": "Harassment or bullying"},
    {"value": "physical_harm", "label": "Imminent physical harm"},
    {"value": "dangerous_acts", "label": "Harmful or dangerous acts"},
    {"value": "self_harm", "label": "Suicide, self-harm or eating disorders"},
    {"value": "misinformation", "label": "Misinformation"},
    {"value": "child_abuse", "label": "Child abuse"},
    {"value": "terrorism", "label": "Promotes terrorism"},
    {"value": "spam", "label": "Spam or misleading"},
    {"value": "legal_issue", "label": "Legal issue"},
  ];

  // =========================
  // HEADERS FOR API
  // =========================
  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStorageService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // =========================
  // SUBMIT REPORT
  // =========================
  Future<void> _submitReport() async {
    if (_isSubmitting || _selectedReason == null) return;

    setState(() => _isSubmitting = true);

    try {
      final headers = await _getHeaders();
      final uri = Uri.parse("$_baseUrl/posts/report");

      final body = {
        "post_id": widget.postId,
        "reason": _selectedReason!,
        if (_messageController.text.trim().isNotEmpty)
          "message": _messageController.text.trim(),
      };

      debugPrint("Submitting report: ${jsonEncode(body)}");

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      debugPrint("Report API Response: ${response.statusCode}");
      debugPrint("Report API Body: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData["status"] == true) {
          // Success - move to success step
          setState(() {
            _currentStep = 2;
          });
        } else {
          // Show error
          _showSnackBar(
              jsonData["message"] ?? "Failed to submit report", Colors.red);
        }
      } else {
        _showSnackBar("Failed to submit report. Please try again.", Colors.red);
      }
    } catch (e) {
      debugPrint("Report API error: $e");
      _showSnackBar("Network error. Please try again.", Colors.red);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // =========================
  // SHOW SNACKBAR
  // =========================
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Report",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  // =========================
  // BODY BUILDER
  // =========================
  Widget _buildBody() {
    if (_currentStep == 0) {
      return _buildReasonSelectionStep();
    } else if (_currentStep == 1) {
      return _buildMessageStep();
    } else {
      return _buildSuccessStep();
    }
  }

  // =========================
  // STEP 1: REASON SELECTION
  // =========================
  Widget _buildReasonSelectionStep() {
    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "What's going on?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "We'll check for all Community Guidelines, so don't worry about making the perfect choice.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Reason List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _reportReasons.length,
              itemBuilder: (context, index) {
                final reason = _reportReasons[index];
                final isSelected = _selectedReason == reason["value"];

                return Card(
                  color: Colors.grey[900],
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    title: Text(
                      reason["label"]!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedReason = reason["value"];
                        } else {
                          _selectedReason = null;
                        }
                      });
                    },
                    activeColor: Colors.red,
                    checkColor: Colors.white,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                );
              },
            ),
          ),

          // Next Button
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedReason != null
                    ? () {
                        setState(() {
                          _currentStep = 1;
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selectedReason != null ? Colors.red : Colors.grey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // STEP 2: MESSAGE INPUT
  // =========================
  Widget _buildMessageStep() {
    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Want to tell us more?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "It's optional. Sharing a few details can help us understand the issue. Please don't include personal info or questions.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Message Input
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: 10,
                minLines: 5,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText: "Type additional details here...",
                  hintStyle: const TextStyle(color: Colors.white60),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),

          // Submit Button
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Back Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep = 0;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "Back",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Submit Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Submit Report",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // STEP 3: SUCCESS MESSAGE
  // =========================
  // Widget _buildSuccessStep() {
  //   return Container(
  //     color: Colors.black,
  //     padding: const EdgeInsets.all(20),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const SizedBox(height: 40),

  //         // Success Icon
  //         Center(
  //           child: Container(
  //             width: 80,
  //             height: 80,
  //             decoration: BoxDecoration(
  //               color: Colors.green,
  //               shape: BoxShape.circle,
  //             ),
  //             child: const Icon(
  //               Icons.check,
  //               size: 40,
  //               color: Colors.white,
  //             ),
  //           ),
  //         ),

  //         const SizedBox(height: 30),

  //         // Success Title
  //         const Text(
  //           "Thanks for helping our community",
  //           style: TextStyle(
  //             color: Colors.white,
  //             fontSize: 24,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),

  //         const SizedBox(height: 16),

  //         // Success Message
  //         Text(
  //           "Your report helps us protect the community from harmful content.",
  //           style: TextStyle(
  //             color: Colors.white70,
  //             fontSize: 16,
  //           ),
  //         ),

  //         const SizedBox(height: 20),

  //         // Important Notice
  //         Card(
  //           color: Colors.grey[900],
  //           child: Padding(
  //             padding: const EdgeInsets.all(16),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 const Text(
  //                   "Important:",
  //                   style: TextStyle(
  //                     color: Colors.white,
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 8),
  //                 Text(
  //                   "If you think someone is in immediate danger, please contact local law enforcement.",
  //                   style: TextStyle(
  //                     color: Colors.white70,
  //                     fontSize: 14,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),

  //         const SizedBox(height: 20),

  //         // What to Expect
  //         Card(
  //           color: Colors.grey[900],
  //           child: Padding(
  //             padding: const EdgeInsets.all(16),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 const Text(
  //                   "What you can expect:",
  //                   style: TextStyle(
  //                     color: Colors.white,
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 12),
  //                 Row(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     const Icon(
  //                       Icons.check_circle,
  //                       color: Colors.green,
  //                       size: 20,
  //                     ),
  //                     const SizedBox(width: 8),
  //                     Expanded(
  //                       child: Text(
  //                         "We'll let you know if we remove this or limit who can see it.",
  //                         style: TextStyle(
  //                           color: Colors.white70,
  //                           fontSize: 14,
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //                 const SizedBox(height: 8),
  //                 Row(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     const Icon(
  //                       Icons.check_circle,
  //                       color: Colors.green,
  //                       size: 20,
  //                     ),
  //                     const SizedBox(width: 8),
  //                     Expanded(
  //                       child: Text(
  //                         "If this channel has serious or repeated violations, we may permanently remove it.",
  //                         style: TextStyle(
  //                           color: Colors.white70,
  //                           fontSize: 14,
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),

  //         const Spacer(),

  //         // OK Button
  //         SizedBox(
  //           width: double.infinity,
  //           child: ElevatedButton(
  //             onPressed: () {
  //               // Close और post_card पर वापस जाएं
  //               Navigator.pop(context);
  //             },
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.red,
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(25),
  //               ),
  //               padding: const EdgeInsets.symmetric(vertical: 16),
  //             ),
  //             child: const Text(
  //               "OK",
  //               style: TextStyle(
  //                 color: Colors.white,
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ),
  //         ),

  //         const SizedBox(height: 20),
  //       ],
  //     ),
  //   );
  // }

  // =========================
// STEP 3: SUCCESS MESSAGE
// =========================
  Widget _buildSuccessStep() {
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        // ✅ SingleChildScrollView add किया
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            // Success Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Success Title
            const Text(
              "Thanks for helping our community",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // Success Message
            Text(
              "Your report helps us protect the community from harmful content.",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 20),

            // Important Notice
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Important:",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "If you think someone is in immediate danger, please contact local law enforcement.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // What to Expect
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "What you can expect:",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "We'll let you know if we remove this or limit who can see it.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "If this channel has serious or repeated violations, we may permanently remove it.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40), // ✅ Spacer() की जगह fixed height

            // OK Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Close और post_card पर वापस जाएं
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:gridcard/core/services/leads-service.dart';
import 'package:gridcard/models/lead_model.dart';

class LeadProviders extends ChangeNotifier {
  List<LeadModel> _leads = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isBackendLive = true;

  List<LeadModel> get leads => _leads;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isBackendLive => _isBackendLive;

  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  int get total => _total;

  String? selectedCategory;

  int _currentPage = 1;
  int _perPage = 10;
  int _lastPage = 1;
  int _total = 0;
  // Current user_id being fetched
  int? _currentUserId;

  String? _search;
  String? _company;
  String? _fromDate;
  String? _toDate;

  bool _isPaginating = false;

  bool get isPaginating => _isPaginating;

  

  Future<void> fetchLeadsByUserId({
    required int userId,
    int perPage = 10,
    bool reset = false,
  }) async {
    if (reset) {
      _currentPage = 1;
      _leads.clear();
      _currentUserId = userId;
      _perPage = perPage;
    }

    if (_currentUserId == userId && _currentPage > _lastPage) return;

    _isLoading = _currentPage == 1;
    _isPaginating = _currentPage > 1;
    _errorMessage = null;

    notifyListeners();

    try {
      final result = await LeadServices.fetchLeadsByUserId(
        userId: userId,
        perPage: _perPage,
        page: _currentPage,
        category: selectedCategory, // ✅ CATEGORY ADDED HERE
      );

      if (result != null) {
        final List<LeadModel> newLeads = result['leads'] as List<LeadModel>;

        final meta = result['meta'] as Map<String, dynamic>;

        _lastPage = meta['last_page'] ?? 1;
        _total = meta['total'] ?? 0;

        if (_currentPage == 1) {
          _leads = newLeads;
        } else {
          _leads.addAll(newLeads);
        }

        _currentPage++;

        notifyListeners();
      } else {
        _errorMessage = "Failed to load leads.";
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = "Connection error: $e";
      notifyListeners();
    }

    _isLoading = false;
    _isPaginating = false;
    notifyListeners();
  }

  

  void setCategory(String? category, int userId) {
    selectedCategory = category;

    fetchLeadsByUserId(
      userId: userId,
      reset: true, // 🔥 RESET PAGE
    );
  }

  Future<void> loadNextPage() async {
    if (_currentPage <= _lastPage && _currentUserId != null) {
      await fetchLeadsByUserId(
        userId: _currentUserId!,
      );
    }
  }

  /// Clear all data (e.g., when logging out)
  void clear() {
    _leads.clear();
    _currentPage = 1;
    _lastPage = 1;
    _total = 0;
    _currentUserId = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> addLead(LeadModel lead) async {
    _isLoading = true;
    notifyListeners();

    final result = await LeadServices.createLead(lead);
    if (result != null) {
      _leads.insert(0, result);
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> fetchLeads() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await LeadServices.fetchLeads();

      debugPrint("📥 API RAW RESULT => $result");

      if (result != null) {
        _leads = result;

        // 🔥 PRINT EACH LEAD
        for (var lead in _leads) {
          debugPrint("🧾 LEAD => ${lead.toJson()}");
        }

        _isBackendLive = true;
      } else {
        _isBackendLive = false;
        _errorMessage =
            "Lead management is currently being synced with the server.";
      }
    } catch (e) {
      _isBackendLive = false;
      _errorMessage = "Connection error. Please try again later.";
      debugPrint("🚨 FETCH ERROR => $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  

  Future<bool> updateLead(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await LeadServices.updateLead(id, data);

      if (result != null) {
        final index = _leads.indexWhere((l) => l.id == id);

        if (index != -1) {
          _leads[index] = result;
        } else {
          // Safety: agar list me na mile to add kar do
          _leads.add(result);
        }

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("🚨 Provider Update Error: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addLeadRaw(Map<String, dynamic> data) async {
    debugPrint("🟢 Provider Received Data => $data");
    _isLoading = true;
    notifyListeners();

    try {
      // ✅ Check if image exists and convert if needed
      if (data.containsKey('lead_image') && data['lead_image'] != null) {
        debugPrint(
            "📸 Image data present, size: ${data['lead_image']?.toString().length ?? 0} characters");
      }

      final result = await LeadServices.createLeadRaw(data);

      if (result) {
        await fetchLeads(); // Refresh list
        _isLoading = false;
        notifyListeners();

        // ✅ Show success message with image info
        if (data.containsKey('image_filename')) {
          debugPrint(
              "✅ Lead saved successfully with image: ${data['image_filename']}");
        }

        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint("❌ Error in addLeadRaw: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchLeadsAdvanced({
    bool reset = false,
    String? search,
    String? company,
    String? fromDate,
    String? toDate,
  }) async {
    if (reset) {
      _currentPage = 1;
      _leads.clear();
    }

    if (_currentPage > _lastPage) return;

    if (_currentPage == 1) {
      _isLoading = true;
    } else {
      _isPaginating = true;
    }

    _search = search ?? _search;
    _company = company ?? _company;
    _fromDate = fromDate ?? _fromDate;
    _toDate = toDate ?? _toDate;

    notifyListeners();

    try {
      final result = await LeadServices.fetchLeadsAdvanced(
        page: _currentPage,
        perPage: _perPage,
        search: _search,
        company: _company,
        fromDate: _fromDate,
        toDate: _toDate,
      );

      if (result != null) {
        final List<LeadModel> newLeads = result['leads'];
        final meta = result['meta'];

        _lastPage = meta['last_page'] ?? 1;

        if (_currentPage == 1) {
          _leads = newLeads;
        } else {
          _leads.addAll(newLeads);
        }

        _currentPage++;
        _isBackendLive = true;
      } else {
        _isBackendLive = false;
      }
    } catch (e) {
      debugPrint("🚨 fetchLeadsAdvanced error => $e");
      _isBackendLive = false;
    }

    _isLoading = false;
    _isPaginating = false;
    notifyListeners();
  }

  Future<bool> deleteLead(int id) async {
    try {
      final success = await LeadServices.deleteLead(id);

      if (success) {
        _leads.removeWhere((e) => e.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("❌ PROVIDER DELETE ERROR => $e");
    }
    return false;
  }
}

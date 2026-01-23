import 'package:flutter/material.dart';
import 'package:gridcard/core/services/lead_service.dart';
import 'package:gridcard/models/customer_master_model.dart';
import 'package:gridcard/models/lead_model.dart';

class LeadProvider extends ChangeNotifier {
  List<CustomerMasterModel> _leads = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isBackendLive = true;

  List<CustomerMasterModel> get leads => _leads;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isBackendLive => _isBackendLive;

  Future<void> fetchLeads() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await LeadService.fetchLeads();
      if (result != null) {
        _leads = result;
        _isBackendLive = true;
      } else {
        // If service returns null, it might be a 404 or other error
        _isBackendLive = false;
        _errorMessage =
            "Lead management is currently being synced with the server.";
      }
    } catch (e) {
      _isBackendLive = false;
      _errorMessage = "Connection error. Please try again later.";
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addLead(CustomerMasterModel lead) async {
    _isLoading = true;
    notifyListeners();

    final result = await LeadService.createLead(lead);
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

  Future<bool> updateLead(int id, CustomerMasterModel lead) async {
    _isLoading = true;
    notifyListeners();

    final result = await LeadService.updateLead(id, lead);
    if (result != null) {
      final index = _leads.indexWhere((l) => l.id == id);
      if (index != -1) {
        _leads[index] = result;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }


}

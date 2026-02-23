int _currentPage = 1;
int _perPage = 10;
int _lastPage = 1;
int _total = 0;

int? _currentUserId;

String? selectedCategory;

bool _isPaginating = false;

bool get isPaginating => _isPaginating;
int get currentPage => _currentPage;
int get lastPage => _lastPage;
int get total => _total;
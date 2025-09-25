import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/task.dart';

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  String _searchQuery = '';
  TaskCategory? _selectedCategory;
  TaskStatus? _selectedStatus;
  TaskPriority? _selectedPriority;
  SortOption _sortOption = SortOption.dueDate;
  bool _showCompleted = true;

  List<Task> get tasks => _tasks;
  List<Task> get filteredTasks => _filteredTasks;
  String get searchQuery => _searchQuery;
  TaskCategory? get selectedCategory => _selectedCategory;
  TaskStatus? get selectedStatus => _selectedStatus;
  TaskPriority? get selectedPriority => _selectedPriority;
  SortOption get sortOption => _sortOption;
  bool get showCompleted => _showCompleted;

  // Statistics
  int get totalTasks => _tasks.length;
  int get completedTasks => _tasks.where((task) => task.status == TaskStatus.completed).length;
  int get pendingTasks => _tasks.where((task) => task.status == TaskStatus.pending).length;
  int get inProgressTasks => _tasks.where((task) => task.status == TaskStatus.inProgress).length;
  int get overdueTasks => _tasks.where((task) => task.isOverdue).length;
  int get todayTasks => _tasks.where((task) => task.isDueToday).length;

  double get completionRate {
    if (_tasks.isEmpty) return 0.0;
    return (completedTasks / totalTasks) * 100;
  }

  TaskProvider() {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getStringList('tasks') ?? [];
    _tasks = tasksJson.map((json) => Task.fromJson(jsonDecode(json))).toList();
    _applyFilters();
    notifyListeners();
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = _tasks.map((task) => jsonEncode(task.toJson())).toList();
    await prefs.setStringList('tasks', tasksJson);
  }

  void addTask(Task task) {
    _tasks.add(task);
    _applyFilters();
    _saveTasks();
    notifyListeners();
  }

  void updateTask(Task updatedTask) {
    final index = _tasks.indexWhere((task) => task.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      _applyFilters();
      _saveTasks();
      notifyListeners();
    }
  }

  void deleteTask(String taskId) {
    _tasks.removeWhere((task) => task.id == taskId);
    _applyFilters();
    _saveTasks();
    notifyListeners();
  }

  void toggleTaskStatus(String taskId) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      TaskStatus newStatus;
      DateTime? completedAt;
      
      switch (task.status) {
        case TaskStatus.pending:
          newStatus = TaskStatus.inProgress;
          break;
        case TaskStatus.inProgress:
          newStatus = TaskStatus.completed;
          completedAt = DateTime.now();
          break;
        case TaskStatus.completed:
          newStatus = TaskStatus.pending;
          break;
        case TaskStatus.cancelled:
          newStatus = TaskStatus.pending;
          break;
      }
      
      _tasks[index] = task.copyWith(
        status: newStatus,
        completedAt: completedAt,
      );
      _applyFilters();
      _saveTasks();
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setSelectedCategory(TaskCategory? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  void setSelectedStatus(TaskStatus? status) {
    _selectedStatus = status;
    _applyFilters();
    notifyListeners();
  }

  void setSelectedPriority(TaskPriority? priority) {
    _selectedPriority = priority;
    _applyFilters();
    notifyListeners();
  }

  void setSortOption(SortOption option) {
    _sortOption = option;
    _applyFilters();
    notifyListeners();
  }

  void setShowCompleted(bool show) {
    _showCompleted = show;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _selectedStatus = null;
    _selectedPriority = null;
    _sortOption = SortOption.dueDate;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    List<Task> filtered = List.from(_tasks);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((task) {
        return task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               task.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               task.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));
      }).toList();
    }

    // Category filter
    if (_selectedCategory != null) {
      filtered = filtered.where((task) => task.category == _selectedCategory).toList();
    }

    // Status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((task) => task.status == _selectedStatus).toList();
    }

    // Priority filter
    if (_selectedPriority != null) {
      filtered = filtered.where((task) => task.priority == _selectedPriority).toList();
    }

    // Show completed filter
    if (!_showCompleted) {
      filtered = filtered.where((task) => task.status != TaskStatus.completed).toList();
    }

    // Sort
    filtered.sort((a, b) {
      switch (_sortOption) {
        case SortOption.dueDate:
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        case SortOption.priority:
          return _getPriorityValue(b.priority).compareTo(_getPriorityValue(a.priority));
        case SortOption.title:
          return a.title.compareTo(b.title);
        case SortOption.createdAt:
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.status:
          return a.status.index.compareTo(b.status.index);
      }
    });

    _filteredTasks = filtered;
  }

  int _getPriorityValue(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 1;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.high:
        return 3;
      case TaskPriority.urgent:
        return 4;
    }
  }

  List<Task> getTasksByCategory(TaskCategory category) {
    return _tasks.where((task) => task.category == category).toList();
  }

  List<Task> getTodayTasks() {
    return _tasks.where((task) => task.isDueToday && task.status != TaskStatus.completed).toList();
  }

  List<Task> getOverdueTasks() {
    return _tasks.where((task) => task.isOverdue).toList();
  }

  List<Task> getUpcomingTasks() {
    final now = DateTime.now();
    final upcoming = now.add(const Duration(days: 7));
    return _tasks.where((task) {
      if (task.dueDate == null || task.status == TaskStatus.completed) return false;
      return task.dueDate!.isAfter(now) && task.dueDate!.isBefore(upcoming);
    }).toList();
  }
}

enum SortOption {
  dueDate,
  priority,
  title,
  createdAt,
  status,
}

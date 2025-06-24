import 'package:flutter/material.dart';
import 'add_page.dart';
import 'models.dart';

enum SortOption {
  timestampAsc,
  timestampDesc,
  tagAsc,
  tagDesc,
}

class MemoHomePage extends StatefulWidget {
  @override
  _MemoHomePageState createState() => _MemoHomePageState();
}

class _MemoHomePageState extends State<MemoHomePage> {
  List<Memo> _memos = [];
  List<Memo> _filteredMemos = [];
  List<String> _tags = [];
  String _searchQuery = '';
  SortOption _sortOption = SortOption.timestampDesc;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterMemos);
  }

  Future<void> _loadData() async {
    final memos = await MemoStorage.loadMemos();
    final tags = await MemoStorage.loadTags();
    setState(() {
      _memos = memos;
      _filteredMemos = memos;
      _tags = tags;
      _sortMemos();
    });
  }

  void _filterMemos() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredMemos = _memos;
      } else {
        _filteredMemos = _memos.where((memo) {
          final title = MemoStorage.extractTitle(memo.content).toLowerCase();
          final tag = memo.tag.toLowerCase();
          return title.contains(_searchQuery) || tag.contains(_searchQuery);
        }).toList();
      }
      _sortMemos();
    });
  }

  void _sortMemos() {
    setState(() {
      switch (_sortOption) {
        case SortOption.timestampAsc:
          _filteredMemos.sort((a, b) =>
              DateTime.parse(a.timestamp).compareTo(DateTime.parse(b.timestamp)));
          break;
        case SortOption.timestampDesc:
          _filteredMemos.sort((a, b) =>
              DateTime.parse(b.timestamp).compareTo(DateTime.parse(a.timestamp)));
          break;
        case SortOption.tagAsc:
          _filteredMemos.sort((a, b) => a.tag.compareTo(b.tag));
          break;
        case SortOption.tagDesc:
          _filteredMemos.sort((a, b) => b.tag.compareTo(a.tag));
          break;
      }
    });
  }

  void _deleteMemo(int index) {
    setState(() {
      _memos.removeAt(index);
      MemoStorage.saveMemos(_memos);
      _filterMemos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('备忘录'),
        actions: [
          DropdownButton<SortOption>(
            value: _sortOption,
            icon: Icon(Icons.sort, color: Colors.white),
            dropdownColor: Colors.blue[50],
            onChanged: (SortOption? newValue) {
              if (newValue != null) {
                setState(() {
                  _sortOption = newValue;
                  _sortMemos();
                });
              }
            },
            items: [
              DropdownMenuItem(
                value: SortOption.timestampDesc,
                child: Text('时间降序'),
              ),
              DropdownMenuItem(
                value: SortOption.timestampAsc,
                child: Text('时间升序'),
              ),
              DropdownMenuItem(
                value: SortOption.tagAsc,
                child: Text('标签升序'),
              ),
              DropdownMenuItem(
                value: SortOption.tagDesc,
                child: Text('标签降序'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索标题或标签...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredMemos.isEmpty
                ? Center(
                child: Text('暂无备忘录', style: TextStyle(fontSize: 18.0)))
                : ListView.builder(
              itemCount: _filteredMemos.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    title: Text(
                      MemoStorage.extractTitle(
                          _filteredMemos[index].content),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16.0, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MemoStorage.formatTimestamp(
                              _filteredMemos[index].timestamp),
                          style: TextStyle(
                              fontSize: 12.0, color: Colors.grey[600]),
                        ),
                        Text(
                          '标签: ${_filteredMemos[index].tag}',
                          style:
                          TextStyle(fontSize: 12.0, color: Colors.blue),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddMemoPage(
                            memo: _filteredMemos[index],
                            index: _memos.indexOf(_filteredMemos[index]),
                            tags: _tags,
                            onSave: (content, timestamp, tag, index) {
                              setState(() {
                                if (tag != null &&
                                    tag.isNotEmpty &&
                                    !_tags.contains(tag)) {
                                  _tags.add(tag);
                                  MemoStorage.saveTags(_tags);
                                }
                                final newMemo = Memo(
                                  content: content,
                                  timestamp: timestamp ??
                                      DateTime.now().toString(),
                                  tag: tag ?? '无标签',
                                );
                                if (index != null) {
                                  _memos[index] = newMemo;
                                } else {
                                  _memos.add(newMemo);
                                }
                                MemoStorage.saveMemos(_memos);
                                _filterMemos();
                              });
                            },
                          ),
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('删除备忘录'),
                            content: Text('确定要删除这条备忘录吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _deleteMemo(
                                      _memos.indexOf(_filteredMemos[index]));
                                  Navigator.pop(context);
                                },
                                child: Text('删除',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddMemoPage(
                tags: _tags,
                onSave: (content, timestamp, tag, _) {
                  setState(() {
                    if (tag != null && tag.isNotEmpty && !_tags.contains(tag)) {
                      _tags.add(tag);
                      MemoStorage.saveTags(_tags);
                    }
                    _memos.add(Memo(
                      content: content,
                      timestamp: timestamp ?? DateTime.now().toString(),
                      tag: tag ?? '无标签',
                    ));
                    MemoStorage.saveMemos(_memos);
                    _filterMemos();
                  });
                },
              ),
            ),
          );
        },
        child: Icon(Icons.add),
        tooltip: '添加备忘录',
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
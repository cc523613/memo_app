import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/database.dart';
import '../providers/memo_provider.dart';
import '../providers/theme_provider.dart';
import '../models/memo.dart';
import 'add_page.dart';
import 'recycle_bin_page.dart';

enum SortOption { timestampAsc, timestampDesc, tagAsc, tagDesc }

class MemoHomePage extends ConsumerStatefulWidget {
  const MemoHomePage({super.key});

  @override
  ConsumerState<MemoHomePage> createState() => _MemoHomePageState();
}

class _MemoHomePageState extends ConsumerState<MemoHomePage> {
  final _searchController = TextEditingController();
  SortOption _sortOption = SortOption.timestampDesc;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(memoProvider.notifier).searchMemos(_searchController.text);
    });
  }

  List<Memo> _sortMemos(List<Memo> memos) {
    final sortedMemos = [...memos];
    switch (_sortOption) {
      case SortOption.timestampAsc:
        sortedMemos.sort((a, b) =>
            DateTime.parse(a.timestamp).compareTo(DateTime.parse(b.timestamp)));
        break;
      case SortOption.timestampDesc:
        sortedMemos.sort((a, b) =>
            DateTime.parse(b.timestamp).compareTo(DateTime.parse(a.timestamp)));
        break;
      case SortOption.tagAsc:
        sortedMemos.sort((a, b) => (a.tag ?? '').compareTo(b.tag ?? ''));
        break;
      case SortOption.tagDesc:
        sortedMemos.sort((a, b) => (b.tag ?? '').compareTo(a.tag ?? ''));
        break;
    }
    return sortedMemos;
  }

  Future<void> _exportMemos(List<Memo> memos) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/memos_export.md');
    final buffer = StringBuffer();
    for (var memo in memos) {
      buffer.writeln('# ${memo.title}');
      buffer.writeln('**Tag**: ${memo.tag ?? '无标签'}');
      buffer.writeln('**Time**: ${memo.timestamp}');
      if (memo.reminderTime != null) {
        buffer.writeln('**Reminder**: ${memo.reminderTime!.toIso8601String()}');
      }
      buffer.writeln('\n${memo.content}\n');
    }
    await file.writeAsString(buffer.toString());
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('备忘录已导出到 ${file.path}')),
      );
    }
  }

  void _showTagManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final tagsAsync = ref.watch(memoProvider.notifier).getTags();
          return AlertDialog(
            title: const Text('管理标签'),
            content: FutureBuilder<List<String>>(
              future: tagsAsync,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final tags = snapshot.data!.where((tag) => tag != '无标签').toList();
                if (tags.isEmpty) {
                  return const Text('暂无标签');
                }
                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      return ListTile(
                        title: Text(tag),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final db = await DatabaseHelper.instance.database;
                            await db.update(
                              'memos',
                              {'tag': null},
                              where: 'tag = ?',
                              whereArgs: [tag],
                            );
                            ref.read(memoProvider.notifier).loadMemos();
                            if (ref.read(tagFilterProvider) == tag) {
                              ref.read(tagFilterProvider.notifier).state = null;
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memos = ref.watch(memoProvider);
    final tagFilter = ref.watch(tagFilterProvider);
    final tagsAsync = ref.watch(memoProvider.notifier).getTags();
    final filteredMemos = tagFilter == null
        ? memos
        : tagFilter == '无标签'
        ? memos.where((memo) => memo.tag == null).toList()
        : memos.where((memo) => memo.tag == tagFilter).toList();
    final sortedMemos = _sortMemos(filteredMemos);

    return Scaffold(
      appBar: AppBar(
        title: const Text('备忘录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecycleBinPage()),
              );
            },
            tooltip: '回收站',
          ),
          IconButton(
            icon: Icon(ref.read(themeProvider) == ThemeMode.dark
                ? Icons.wb_sunny
                : Icons.nights_stay),
            onPressed: () {
              ref.read(themeProvider.notifier).state =
              ref.read(themeProvider) == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
            tooltip: '切换主题',
          ),
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: () => _exportMemos(memos),
            tooltip: '导出备忘录',
          ),
          IconButton(
            icon: const Icon(Icons.label),
            onPressed: _showTagManagementDialog,
            tooltip: '管理标签',
          ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortOption = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.timestampDesc,
                child: Text('时间降序'),
              ),
              const PopupMenuItem(
                value: SortOption.timestampAsc,
                child: Text('时间升序'),
              ),
              const PopupMenuItem(
                value: SortOption.tagAsc,
                child: Text('标签升序'),
              ),
              const PopupMenuItem(
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
                hintText: '搜索标题或内容...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
                    : null,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<String>>(
                    future: tagsAsync,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox();
                      }
                      final tags = ['全部', ...snapshot.data!];
                      return DropdownButton<String>(
                        hint: const Text('选择标签'),
                        value: tagFilter,
                        isExpanded: true,
                        items: tags.map((tag) {
                          return DropdownMenuItem<String>(
                            value: tag == '全部' ? null : tag,
                            child: Text(tag),
                          );
                        }).toList(),
                        onChanged: (value) {
                          ref.read(tagFilterProvider.notifier).state = value;
                        },
                      );
                    },
                  ),
                ),
                if (tagFilter != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      ref.read(tagFilterProvider.notifier).state = null;
                    },
                    tooltip: '清除筛选',
                  ),
              ],
            ),
          ),
          Expanded(
            child: sortedMemos.isEmpty
                ? const Center(
                child: Text('暂无备忘录', style: TextStyle(fontSize: 18)))
                : ListView.builder(
              itemCount: sortedMemos.length,
              itemBuilder: (context, index) {
                final memo = sortedMemos[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    title: Text(
                      memo.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm:ss')
                              .format(DateTime.parse(memo.timestamp)),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '标签: ${memo.tag ?? '无标签'}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.blue),
                        ),
                        if (memo.reminderTime != null)
                          Text(
                            '提醒: ${DateFormat('yyyy-MM-dd HH:mm').format(memo.reminderTime!)}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.green),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddMemoPage(memo: memo),
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('删除备忘录'),
                            content:
                            const Text('确定要将此备忘录移到回收站吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(memoProvider.notifier)
                                      .deleteMemo(memo.id!);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                        content: Text('已移到回收站')),
                                  );
                                },
                                child: const Text('删除',
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
            MaterialPageRoute(builder: (context) => const AddMemoPage()),
          );
        },
        child: const Icon(Icons.add),
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
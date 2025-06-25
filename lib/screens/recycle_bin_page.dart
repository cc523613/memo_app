import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/memo_provider.dart';
import '../models/memo.dart';
import 'package:intl/intl.dart';

class RecycleBinPage extends ConsumerWidget {
  const RecycleBinPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedMemos = ref.watch(deletedMemoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
      ),
      body: deletedMemos.isEmpty
          ? const Center(
          child: Text('回收站为空', style: TextStyle(fontSize: 18)))
          : ListView.builder(
        itemCount: deletedMemos.length,
        itemBuilder: (context, index) {
          final memo = deletedMemos[index];
          return Card(
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '标签: ${memo.tag ?? '无标签'}',
                    style:
                    const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.restore, color: Colors.green),
                    onPressed: () {
                      ref
                          .read(deletedMemoProvider.notifier)
                          .restoreMemo(memo.id!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已恢复备忘录')),
                      );
                    },
                    tooltip: '恢复',
                  ),
                  IconButton(
                    icon:
                    const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('永久删除'),
                          content:
                          const Text('确定要永久删除此备忘录吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                ref
                                    .read(deletedMemoProvider.notifier)
                                    .deleteMemo(memo.id!);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('已永久删除')),
                                );
                              },
                              child: const Text('删除',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    tooltip: '永久删除',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
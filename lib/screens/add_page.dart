import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../providers/memo_provider.dart';
import '../models/memo.dart';
import '../models/database.dart';

class AddMemoPage extends ConsumerStatefulWidget {
  final Memo? memo;

  const AddMemoPage({super.key, this.memo});

  @override
  ConsumerState<AddMemoPage> createState() => _AddMemoPageState();
}

class _AddMemoPageState extends ConsumerState<AddMemoPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  DateTime? _reminderTime;
  final _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    if (widget.memo != null) {
      _titleController.text = widget.memo!.title;
      _contentController.text = widget.memo!.content;
      _tagController.text = widget.memo!.tag ?? '';
      _reminderTime = widget.memo!.reminderTime;
    }
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    try {
      await _notificationsPlugin.initialize(settings);
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('通知初始化失败: $e');
    }
  }

  Future<void> _scheduleNotification(Memo memo) async {
    if (memo.reminderTime == null || memo.id == null) return;
    final androidDetails = const AndroidNotificationDetails(
      'memo_channel',
      'Memo Reminders',
      channelDescription: 'Notifications for memo reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    final iosDetails = const DarwinNotificationDetails();
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    try {
      await _notificationsPlugin.zonedSchedule(
        memo.id!,
        memo.title,
        memo.content.length > 50
            ? '${memo.content.substring(0, 47)}...'
            : memo.content,
        tz.TZDateTime.from(memo.reminderTime!, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('通知已调度: ID=${memo.id}, 时间=${memo.reminderTime}');
    } catch (e) {
      debugPrint('通知调度失败: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('通知设置失败: $e')),
        );
      }
    }
  }

  Future<void> _cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      debugPrint('通知已取消: ID=$id');
    } catch (e) {
      debugPrint('通知取消失败: $e');
    }
  }

  Future<void> _selectReminderTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
      );
      if (time != null) {
        setState(() {
          _reminderTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(memoProvider.notifier).getTags();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memo == null ? '添加备忘录' : '编辑备忘录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _titleController.clear();
              _contentController.clear();
              _tagController.clear();
              setState(() { _reminderTime = null; });
            },
            tooltip: '清除输入',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              final title = _titleController.text.trim();
              final content = _contentController.text.trim();
              if (title.isEmpty || content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入标题和内容')),
                );
                return;
              }
              final normalizedTag = _tagController.text.trim().toLowerCase();
              final memo = Memo(
                id: widget.memo?.id,
                title: title,
                content: content,
                timestamp: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
                tag: normalizedTag.isEmpty ? null : normalizedTag,
                reminderTime: _reminderTime,
                isDeleted: false,
              );

              try {
                debugPrint('保存备忘录: ${memo.toMap()}');
                if (widget.memo != null) {
                  // 更新现有备忘录
                  if (widget.memo!.reminderTime != null) {
                    await _cancelNotification(widget.memo!.id!);
                  }
                  await ref.read(memoProvider.notifier).updateMemo(memo);
                  if (_reminderTime != null) {
                    await _scheduleNotification(memo);
                  }
                } else {
                  // 插入新备忘录
                  final newMemo = await ref.read(memoProvider.notifier).addMemoAndReturn(memo);
                  if (_reminderTime != null) {
                    await _scheduleNotification(newMemo);
                  }
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('备忘录已保存')),
                  );
                }
              } catch (e) {
                debugPrint('保存失败: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存失败: $e')),
                  );
                }
              }
            },
            tooltip: '保存',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '请输入备忘录标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                labelText: '标签',
                hintText: '输入标签（如：工作）',
                border: const OutlineInputBorder(),
                suffixIcon: _tagController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _tagController.clear();
                    setState(() {});
                  },
                )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<String>>(
              future: tagsAsync,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('加载标签失败: ${snapshot.error}');
                }
                final tags = snapshot.data ?? ['无标签'];
                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: tags
                      .where((tag) => tag != '无标签')
                      .map((tag) => ChoiceChip(
                    label: Text(tag),
                    selected: _tagController.text.trim().toLowerCase() == tag,
                    onSelected: (selected) {
                      setState(() {
                        _tagController.text = selected ? tag : '';
                      });
                    },
                  ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '提醒时间: ${_reminderTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(_reminderTime!) : '未设置'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.alarm),
                  onPressed: _selectReminderTime,
                  tooltip: '设置提醒',
                ),
                if (_reminderTime != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() { _reminderTime = null; });
                    },
                    tooltip: '取消提醒',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '内容',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '请输入备忘录内容',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }
}
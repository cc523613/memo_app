import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../providers/memo_provider.dart';
import '../models/memo.dart';

class AddMemoPage extends ConsumerStatefulWidget {
  final Memo? memo;

  const AddMemoPage({super.key, this.memo, required Null Function(dynamic Memo) onSave});

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
    tz.initializeTimeZones(); // Initialize timezone data
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
    await _notificationsPlugin.initialize(settings);
    // Request permissions for iOS
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    // Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _scheduleNotification(Memo memo) async {
    if (memo.reminderTime == null) return;
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
    await _notificationsPlugin.zonedSchedule(
      memo.id ?? DateTime.now().millisecondsSinceEpoch,
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
  }

  Future<void> _cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
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
              setState(() {
                _reminderTime = null;
              });
            },
            tooltip: '清除输入',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              if (_titleController.text.isEmpty ||
                  _contentController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入标题和内容')),
                );
                return;
              }
              final memo = Memo(
                id: widget.memo?.id,
                title: _titleController.text,
                content: _contentController.text,
                timestamp: widget.memo?.timestamp ?? DateTime.now().toString(),
                tag: _tagController.text.isEmpty ? null : _tagController.text,
                reminderTime: _reminderTime,
              );
              if (widget.memo != null) {
                if (widget.memo!.reminderTime != null) {
                  await _cancelNotification(widget.memo!.id!);
                }
                ref.read(memoProvider.notifier).updateMemo(memo);
              } else {
                ref.read(memoProvider.notifier).addMemo(memo);
              }
              if (_reminderTime != null) {
                await _scheduleNotification(memo);
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '请输入备忘录标题',
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<String>>(
              future: tagsAsync,
              builder: (context, snapshot) {
                final tags = snapshot.data ?? ['无标签'];
                return Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return tags;
                    return tags.where((tag) => tag
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (selection) {
                    _tagController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    _tagController.text = controller.text;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: '标签',
                        hintText: '例如：工作、生活',
                      ),
                      onSubmitted: (_) => onSubmitted(),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '提醒时间: ${_reminderTime != null ? DateFormat('yyyy-MM-dd HH:mm').format(_reminderTime!) : '未设置'}',
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.alarm),
                  onPressed: _selectReminderTime,
                  tooltip: '设置提醒',
                ),
                if (_reminderTime != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _reminderTime = null;
                      });
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
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: '请输入备忘录内容',
                ),
                autofocus: true,
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
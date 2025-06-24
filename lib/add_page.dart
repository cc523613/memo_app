import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'models.dart';

class AddMemoPage extends StatefulWidget {
  final Memo? memo; // 编辑时的备忘录
  final int? index; // 编辑时的索引
  final List<String> tags; // 可用标签
  final Function(String, String?, String?, int?) onSave; // 保存回调

  AddMemoPage({
    this.memo,
    this.index,
    required this.tags,
    required this.onSave,
  });

  @override
  _AddMemoPageState createState() => _AddMemoPageState();
}

class _AddMemoPageState extends State<AddMemoPage> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  bool _showPreview = true;

  @override
  void initState() {
    super.initState();
    if (widget.memo != null) {
      _contentController.text = widget.memo!.content;
      _tagController.text = widget.memo!.tag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.memo == null ? '添加备忘录' : '编辑备忘录'),
        actions: [
          IconButton(
            icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showPreview = !_showPreview;
              });
            },
            tooltip: _showPreview ? '隐藏预览' : '显示预览',
          ),
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              _contentController.clear();
              _tagController.clear();
            },
            tooltip: '清除输入',
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () {
              if (_contentController.text.isNotEmpty) {
                widget.onSave(
                  _contentController.text,
                  widget.memo != null ? widget.memo!.timestamp : null,
                  _tagController.text.isEmpty ? null : _tagController.text,
                  widget.index,
                );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请输入内容')),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return widget.tags;
                }
                return widget.tags.where((tag) => tag
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (String selection) {
                _tagController.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                _tagController.text = controller.text;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: '标签（输入或选择已有标签）',
                    hintText: '例如：会议、购物',
                  ),
                  onSubmitted: (_) => onFieldSubmitted(),
                );
              },
            ),
            SizedBox(height: 16.0),
            Text(
              '内容（支持 Markdown 格式，例如 **加粗**、*斜体*、- 列表）',
              style: TextStyle(fontSize: 14.0, color: Colors.grey[700]),
            ),
            SizedBox(height: 8.0),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: '请输入备忘录内容',
                      ),
                      autofocus: true,
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  if (_showPreview && _contentController.text.isNotEmpty) ...[
                    Divider(height: 16.0),
                    Text(
                      '预览',
                      style: TextStyle(fontSize: 14.0, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 8.0),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Markdown(
                          data: _contentController.text,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(fontSize: 16.0),
                            strong: TextStyle(fontWeight: FontWeight.bold),
                            em: TextStyle(fontStyle: FontStyle.italic),
                            listBullet: TextStyle(fontSize: 16.0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }
}
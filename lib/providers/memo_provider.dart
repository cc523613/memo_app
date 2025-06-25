import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/memo.dart';
import '../models/database.dart';

final memoProvider = StateNotifierProvider<MemoNotifier, List<Memo>>((ref) {
  return MemoNotifier();
});

class MemoNotifier extends StateNotifier<List<Memo>> {
  MemoNotifier() : super([]) {
    loadMemos();
  }

  Future<void> loadMemos() async {
    state = await DatabaseHelper.instance.getMemos();
  }

  Future<void> addMemo(Memo memo) async {
    await DatabaseHelper.instance.insertMemo(memo);
    await loadMemos();
  }

  Future<void> updateMemo(Memo memo) async {
    await DatabaseHelper.instance.updateMemo(memo);
    await loadMemos();
  }

  Future<void> deleteMemo(int id, {bool permanent = false}) async {
    await DatabaseHelper.instance.deleteMemo(id, permanent: permanent);
    await loadMemos();
  }

  Future<void> restoreMemo(int id) async {
    await DatabaseHelper.instance.restoreMemo(id);
    await loadMemos();
  }

  Future<void> searchMemos(String query) async {
    if (query.isEmpty) {
      await loadMemos();
    } else {
      state = await DatabaseHelper.instance.searchMemos(query);
    }
  }

  Future<List<String>> getTags() async {
    return await DatabaseHelper.instance.getTags();
  }
}

final deletedMemoProvider =
StateNotifierProvider<DeletedMemoNotifier, List<Memo>>((ref) {
  return DeletedMemoNotifier();
});

class DeletedMemoNotifier extends StateNotifier<List<Memo>> {
  DeletedMemoNotifier() : super([]) {
    loadDeletedMemos();
  }

  Future<void> loadDeletedMemos() async {
    state = await DatabaseHelper.instance.getDeletedMemos();
  }

  Future<void> restoreMemo(int id) async {
    await DatabaseHelper.instance.restoreMemo(id);
    await loadDeletedMemos();
  }

  Future<void> deleteMemo(int id) async {
    await DatabaseHelper.instance.deleteMemo(id, permanent: true);
    await loadDeletedMemos();
  }
}

final tagFilterProvider = StateProvider<String?>((ref) => null);
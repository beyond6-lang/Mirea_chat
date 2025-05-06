import 'dart:developer';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/common/constants.dart';
import '../core/common/constants.dart';
import '../data/hive/boxes.dart';
import '../data/model/message.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(ChatState());

  final List<Message> _inChatMessages = [];
  final List<XFile>? _imagesFileList = [];
  int _currentIndex = 0;
  String _currentChatId = '';
  String _modelType = 'gemini-pro';
  GenerativeModel? _model;

  void initializeChat({required String chatId}) async {
    emit(state.copyWith(status: ChatStatus.loading));

    try {
      final messages = await _loadMessagesFromDB(chatId);
      _currentChatId = chatId;
      _inChatMessages.clear();
      _inChatMessages.addAll(messages);

      emit(ChatLoaded(
        messages: _inChatMessages,
        currentIndex: _currentIndex,
        currentChatId: _currentChatId,
        imagesFileList: _imagesFileList,
        modelType: _modelType,
      ));
    } catch (e) {
      emit(state.copyWith(
          status: ChatStatus.error, error: "Failed to create chat room $e"));
    }


  Future<List<Message>> _loadMessagesFromDB(String chatId) async {
    await Hive.openBox('${Constants.chatMessagesBox}$chatId');
    final messageBox = Hive.box('${Constants.chatMessagesBox}$chatId');

    return messageBox.keys.map((e) {
      final message = messageBox.get(e);
      return Message.fromMap(Map<String, dynamic>.from(message));
    }).toList();
  }

  void setModel(String newModel) {
    _modelType = newModel;
    emit(ChatLoaded(
      messages: _inChatMessages,
      currentIndex: _currentIndex,
      currentChatId: _currentChatId,
      imagesFileList: _imagesFileList,
      modelType: _modelType,
    ));
  }

  Future<void> sendMessage({required String message, required bool isTextOnly}) async {
    emit(ChatLoading());

    try {
      await _setModel(isTextOnly, message);
      final chatId = _currentChatId.isNotEmpty ? _currentChatId : const Uuid().v4();

      final userMessage = Message(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: chatId,
        role: Role.user,
        message: StringBuffer(message),
        imagesUrls: [],
        timeSent: DateTime.now(),
      );

      _inChatMessages.add(userMessage);
      _currentChatId = chatId;

      emit(ChatLoaded(
        messages: _inChatMessages,
        currentIndex: _currentIndex,
        currentChatId: _currentChatId,
        imagesFileList: _imagesFileList,
        modelType: _modelType,
      ));

      await _sendMessageToModel(message, isTextOnly);
    } catch (e) {
      emit(ChatError(message: 'Error sending message: $e'));
    }
  }

  Future<void> _setModel(bool isTextOnly, String prompt) async {
    if (isTextOnly) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _getApiKey(),
        generationConfig: GenerationConfig(
          temperature: 0.4,
          topK: 32,
          topP: 1,
          maxOutputTokens: 4096,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.high),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.high),
        ],
      );
    }
  }

  Future<void> _sendMessageToModel(String message, bool isTextOnly) async {
    final chatSession = _model!.startChat(history: []);
    final content = Content.text(message);

    final assistantMessage = Message(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: _currentChatId,
      role: Role.assistant,
      message: StringBuffer(),
      timeSent: DateTime.now(),
    );

    _inChatMessages.add(assistantMessage);
    emit(ChatLoaded(
      messages: _inChatMessages,
      currentIndex: _currentIndex,
      currentChatId: _currentChatId,
      imagesFileList: _imagesFileList,
      modelType: _modelType,
    ));

    chatSession.sendMessageStream(content).asyncMap((event) {
      return event;
    }).listen((event) {
      _inChatMessages
          .firstWhere((element) => element.messageId == assistantMessage.messageId)
          .message
          .write(event.text);
      log('event: ${event.text}');

      emit(ChatLoaded(
        messages: _inChatMessages,
        currentIndex: _currentIndex,
        currentChatId: _currentChatId,
        imagesFileList: _imagesFileList,
        modelType: _modelType,
      ));
    }, onDone: () async {
      log('Response complete');
      emit(ChatLoaded(
        messages: _inChatMessages,
        currentIndex: _currentIndex,
        currentChatId: _currentChatId,
        imagesFileList: _imagesFileList,
        modelType: _modelType,
      ));
    }).onError((error, stackTrace) {
      emit(ChatError(message: 'Error: $error'));
    });
  }

  Future<void> deleteChatMessages(String chatId) async {
    try {
      if (!Hive.isBoxOpen('${Constants.chatMessagesBox}$chatId')) {
        await Hive.openBox('${Constants.chatMessagesBox}$chatId');
      }
      await Hive.box('${Constants.chatMessagesBox}$chatId').clear();

      _inChatMessages.clear();
      _currentChatId = '';

      emit(ChatLoaded(
        messages: _inChatMessages,
        currentIndex: _currentIndex,
        currentChatId: '',
        imagesFileList: _imagesFileList,
        modelType: _modelType,
      ));
    } catch (e) {
      emit(ChatError(message: 'Failed to delete messages: $e'));
    }
  }

  String _getApiKey() {
    return dotenv.env['GEMINI_API_KEY'].toString();
  }
}

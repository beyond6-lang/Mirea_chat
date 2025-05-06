import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/model/message.dart';


enum ChatStatus {
  inital,
  loading,
  loaded,
  error,
}
class ChatState extends Equatable{
  final List<Message> messages;
  final int currentIndex;
  final String currentChatId;
  final List<XFile>? imagesFileList;
  final String modelType;

  const ChatState({
    required this.messages,
    required this.currentIndex,
    required this.currentChatId,
    this.imagesFileList,
    required this.modelType,
  });

  @override
  List<Object?> get props => [messages, currentIndex, currentChatId, imagesFileList, modelType];
}



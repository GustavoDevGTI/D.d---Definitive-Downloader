import 'dart:async';
import 'dart:io';
import '../platform/media_publication.dart';

String operationMessage(Object error) {
  if (error is MediaPublicationFailure) return error.message;
  if (error is HandshakeException) {
    return 'Não foi possível validar o certificado da conexão. Verifique a rede e os certificados do sistema; você também pode importar um CSV.';
  }
  if (error is TimeoutException) {
    return 'O serviço demorou para responder. Tente novamente mais tarde.';
  }
  if (error is SocketException) {
    return 'Não foi possível conectar ao serviço. Verifique sua conexão e tente novamente.';
  }
  if (error is FormatException) return error.message;
  if (error is HttpException) return error.message;
  if (error is FileSystemException) return error.message;
  return 'Não foi possível concluir a operação. ${error.toString().replaceFirst('Exception: ', '')}';
}

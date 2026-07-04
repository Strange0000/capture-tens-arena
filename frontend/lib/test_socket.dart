import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() async {
  print('Testing backend socket...');
  final baseUrl = 'https://capture-tens-arena.onrender.com';
  
  // 1. Guest login
  print('Logging in as guest...');
  final res = await http.post(Uri.parse('$baseUrl/auth/guest'));
  if (res.statusCode >= 400) {
    print('HTTP ERROR: ${res.statusCode}');
    return;
  }
  
  final data = jsonDecode(res.body);
  final token = data['token'];
  print('Got token: $token');
  
  // 2. Connect socket
  final socket = IO.io(baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .disableAutoConnect()
      .build());

  socket.onConnect((_) {
    print('Socket connected!');
    print('Starting bot match...');
    socket.emit('bot:offline', {'difficulty': 'hard'});
  });

  socket.on('match:created', (data) {
    print('Match created: $data');
  });

  socket.on('match:state', (data) {
    print('Match state received!');
    print('Phase: ${data['phase']}');
    socket.disconnect();
  });

  socket.onConnectError((err) => print('Connect Error: $err'));
  socket.onError((err) => print('Error: $err'));
  
  socket.connect();
}

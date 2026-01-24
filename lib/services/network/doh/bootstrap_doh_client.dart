import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../network_logger.dart';

/// DNS 记录类型
enum DnsRecordType {
  a(1), // IPv4
  aaaa(28); // IPv6

  const DnsRecordType(this.value);
  final int value;
}

/// 支持 Bootstrap IP 的 DOH 客户端
/// 类似 Chrome 的实现：预置 DOH 服务器的 IP，直接连接，绕过 DNS 解析
class BootstrapDohClient {
  BootstrapDohClient({
    required this.serverUrl,
    this.bootstrapIps = const [],
    this.timeout = const Duration(seconds: 5),
    this.preferIPv6 = false,
  }) {
    _parseServerUrl();
  }

  final String serverUrl;
  final List<String> bootstrapIps;
  final Duration timeout;
  /// 是否优先使用 IPv6 连接 DOH 服务
  bool preferIPv6;

  late String _host;
  late int _port;
  late String _path;

  void _parseServerUrl() {
    final uri = Uri.parse(serverUrl);
    _host = uri.host;
    _port = uri.port == 0 ? 443 : uri.port;
    _path = uri.path.isEmpty ? '/dns-query' : uri.path;
  }

  /// 查询单个地址
  Future<InternetAddress?> lookup(String host) async {
    final addresses = await lookupAll(host);
    return addresses.isNotEmpty ? addresses.first : null;
  }

  /// 查询所有地址（同时查询 A 和 AAAA 记录）
  Future<List<InternetAddress>> lookupAll(String host) async {
    // 并行查询 A 和 AAAA 记录
    final results = await Future.wait([
      _lookupByType(host, DnsRecordType.a),
      _lookupByType(host, DnsRecordType.aaaa),
    ]);

    final addresses = <InternetAddress>[
      ...results[0], // IPv4
      ...results[1], // IPv6
    ];

    return addresses;
  }

  /// 按记录类型查询地址
  Future<List<InternetAddress>> _lookupByType(String host, DnsRecordType type) async {
    try {
      // 构建 DNS 查询消息
      final query = _buildDnsQuery(host, type: type);
      final base64Query = base64Url.encode(query).replaceAll('=', '');

      // 使用 GET 方法
      final requestPath = '$_path?dns=$base64Query';

      // 尝试连接
      SecureSocket? socket;
      Object? lastError;

      if (bootstrapIps.isNotEmpty) {
        // 使用 Bootstrap IP 直接连接
        final ipv4 = bootstrapIps.where((ip) => !ip.contains(':')).toList();
        final ipv6 = bootstrapIps.where((ip) => ip.contains(':')).toList();
        // 根据 preferIPv6 设置决定优先顺序
        final sortedIps = preferIPv6 ? [...ipv6, ...ipv4] : [...ipv4, ...ipv6];

        NetworkLogger.log('[DOH] 使用 Bootstrap IP 连接 $_host (IPv6优先: $preferIPv6): $sortedIps');

        for (final ip in sortedIps) {
          try {
            final address = InternetAddress(ip);
            // 1. 先用普通 Socket 连接 IP
            final rawSocket = await Socket.connect(
              address,
              _port,
              timeout: timeout,
            );
            // 2. 升级为 TLS，指定 host 参数设置 SNI 为域名
            socket = await SecureSocket.secure(
              rawSocket,
              host: _host, // SNI 使用域名，确保证书验证正确
            );
            NetworkLogger.log('[DOH] Bootstrap IP 连接成功: $ip');
            break;
          } catch (e) {
            lastError = e;
            NetworkLogger.log('[DOH] Bootstrap IP 连接失败: $ip | $e');
            continue;
          }
        }
      } else {
        // 没有 Bootstrap IP，使用系统 DNS 解析后连接
        try {
          socket = await SecureSocket.connect(
            _host,
            _port,
            timeout: timeout,
          );
        } catch (e) {
          lastError = e;
        }
      }

      if (socket == null) {
        throw lastError ?? SocketException('无法连接到 DOH 服务');
      }

      try {
        // 发送 HTTP/1.1 请求
        final request = StringBuffer()
          ..writeln('GET $requestPath HTTP/1.1')
          ..writeln('Host: $_host')
          ..writeln('Accept: application/dns-message')
          ..writeln('Connection: close')
          ..writeln();

        socket.write(request.toString());
        await socket.flush();

        // 读取响应
        final response = await socket.fold<List<int>>(
          <int>[],
          (previous, element) => previous..addAll(element),
        ).timeout(timeout);

        // 解析 HTTP 响应
        final responseStr = utf8.decode(response, allowMalformed: true);
        final headerEnd = responseStr.indexOf('\r\n\r\n');
        if (headerEnd == -1) {
          throw HttpException('无效的 HTTP 响应');
        }

        final headers = responseStr.substring(0, headerEnd);
        final statusLine = headers.split('\r\n').first;

        // 检查状态码
        if (!statusLine.contains('200')) {
          throw HttpException('DOH 服务器返回错误: $statusLine');
        }

        // 提取 body（跳过 headers + \r\n\r\n）
        final bodyStart = headerEnd + 4;
        final body = Uint8List.fromList(response.sublist(bodyStart));

        // 处理 chunked 编码
        final Uint8List dnsResponse;
        if (headers.toLowerCase().contains('transfer-encoding: chunked')) {
          dnsResponse = _decodeChunked(body);
        } else {
          dnsResponse = body;
        }

        return _parseDnsResponse(dnsResponse);
      } finally {
        await socket.close();
      }
    } catch (e) {
      NetworkLogger.log('[DOH] 查询失败: $host | $e');
      rethrow;
    }
  }

  /// 解码 chunked 传输编码
  Uint8List _decodeChunked(Uint8List data) {
    final result = BytesBuilder();
    var offset = 0;

    while (offset < data.length) {
      // 查找 chunk size 行的结尾
      var lineEnd = offset;
      while (lineEnd < data.length - 1) {
        if (data[lineEnd] == 0x0D && data[lineEnd + 1] == 0x0A) {
          break;
        }
        lineEnd++;
      }

      if (lineEnd >= data.length - 1) break;

      // 解析 chunk size
      final sizeStr = utf8.decode(data.sublist(offset, lineEnd));
      final chunkSize = int.tryParse(sizeStr.trim(), radix: 16) ?? 0;

      if (chunkSize == 0) break;

      // 跳过 \r\n
      offset = lineEnd + 2;

      // 读取 chunk 数据
      if (offset + chunkSize <= data.length) {
        result.add(data.sublist(offset, offset + chunkSize));
      }

      // 跳过 chunk 数据和结尾的 \r\n
      offset += chunkSize + 2;
    }

    return result.toBytes();
  }

  /// 构建 DNS 查询消息 (RFC 1035)
  Uint8List _buildDnsQuery(String host, {DnsRecordType type = DnsRecordType.a}) {
    final buffer = BytesBuilder();

    // Transaction ID (2 bytes) - 随机
    buffer.addByte(0x00);
    buffer.addByte(0x01);

    // Flags (2 bytes) - 标准查询，递归
    buffer.addByte(0x01); // RD = 1
    buffer.addByte(0x00);

    // Questions (2 bytes) - 1 个问题
    buffer.addByte(0x00);
    buffer.addByte(0x01);

    // Answer RRs (2 bytes) - 0
    buffer.addByte(0x00);
    buffer.addByte(0x00);

    // Authority RRs (2 bytes) - 0
    buffer.addByte(0x00);
    buffer.addByte(0x00);

    // Additional RRs (2 bytes) - 0
    buffer.addByte(0x00);
    buffer.addByte(0x00);

    // Question section - QNAME
    final labels = host.split('.');
    for (final label in labels) {
      buffer.addByte(label.length);
      buffer.add(utf8.encode(label));
    }
    buffer.addByte(0x00); // 结束标记

    // QTYPE (2 bytes) - A 记录 = 1, AAAA 记录 = 28
    buffer.addByte((type.value >> 8) & 0xFF);
    buffer.addByte(type.value & 0xFF);

    // QCLASS (2 bytes) - IN = 1
    buffer.addByte(0x00);
    buffer.addByte(0x01);

    return buffer.toBytes();
  }

  /// 解析 DNS 响应
  List<InternetAddress> _parseDnsResponse(Uint8List data) {
    if (data.length < 12) return [];

    final addresses = <InternetAddress>[];

    // 跳过头部 (12 bytes)
    var offset = 12;

    // 跳过问题部分
    final qdcount = (data[4] << 8) | data[5];
    for (var i = 0; i < qdcount; i++) {
      offset = _skipName(data, offset);
      offset += 4; // QTYPE + QCLASS
    }

    // 解析回答部分
    final ancount = (data[6] << 8) | data[7];
    for (var i = 0; i < ancount; i++) {
      if (offset >= data.length) break;

      // 跳过 NAME
      offset = _skipName(data, offset);
      if (offset + 10 > data.length) break;

      // TYPE (2 bytes)
      final type = (data[offset] << 8) | data[offset + 1];
      offset += 2;

      // CLASS (2 bytes)
      offset += 2;

      // TTL (4 bytes)
      offset += 4;

      // RDLENGTH (2 bytes)
      final rdlength = (data[offset] << 8) | data[offset + 1];
      offset += 2;

      if (offset + rdlength > data.length) break;

      // RDATA
      if (type == 1 && rdlength == 4) {
        // A 记录 (IPv4)
        final ip = '${data[offset]}.${data[offset + 1]}.${data[offset + 2]}.${data[offset + 3]}';
        addresses.add(InternetAddress(ip));
      } else if (type == 28 && rdlength == 16) {
        // AAAA 记录 (IPv6)
        final parts = <String>[];
        for (var j = 0; j < 16; j += 2) {
          parts.add(((data[offset + j] << 8) | data[offset + j + 1]).toRadixString(16));
        }
        addresses.add(InternetAddress(parts.join(':')));
      }

      offset += rdlength;
    }

    return addresses;
  }

  /// 跳过 DNS 名称字段
  int _skipName(Uint8List data, int offset) {
    while (offset < data.length) {
      final len = data[offset];
      if (len == 0) {
        return offset + 1;
      } else if ((len & 0xC0) == 0xC0) {
        // 压缩指针
        return offset + 2;
      } else {
        offset += len + 1;
      }
    }
    return offset;
  }

  void close() {
    // 无需清理，每次请求都是新连接
  }
}

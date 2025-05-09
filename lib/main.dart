import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

// アプリのエントリーポイント
void main() {
  runApp(ExampleNetworkStateApp());
}

// ネットワーク状態の振る舞いを定義するmixin
mixin NetworkStateBehavior {
  // 状態に応じたテキストを取得
  String get statusMessage;
  
  // 状態に応じた色を取得
  Color get statusColor;
  
  // 状態に応じたアイコンを取得
  IconData get statusIcon;
  
  // 状態に応じたアクションを定義
  Widget buildActionButton(VoidCallback onPressed);
  
  // ログ記録機能
  void log(String message) {
    debugPrint('NETWORK_STATE: $message');
  }
}

// ネットワーク状態を表すenum
enum NetworkState with NetworkStateBehavior {
  online,
  offline,
  serverDown,
  checking,
  unknown;
  
  @override
  String get statusMessage {
    switch (this) {
      case NetworkState.online:
        return 'オンライン：接続は正常です';
      case NetworkState.offline:
        return 'オフライン：インターネットに接続されていません';
      case NetworkState.serverDown:
        return 'サーバーエラー：サーバーに接続できません';
      case NetworkState.checking:
        return '接続を確認中...';
      case NetworkState.unknown:
        return '接続状態が不明です';
    }
  }
  
  @override
  Color get statusColor {
    switch (this) {
      case NetworkState.online:
        return Colors.green;
      case NetworkState.offline:
        return Colors.red;
      case NetworkState.serverDown:
        return Colors.orange;
      case NetworkState.checking:
        return Colors.blue;
      case NetworkState.unknown:
        return Colors.grey;
    }
  }
  
  @override
  IconData get statusIcon {
    switch (this) {
      case NetworkState.online:
        return Icons.wifi;
      case NetworkState.offline:
        return Icons.wifi_off;
      case NetworkState.serverDown:
        return Icons.cloud_off;
      case NetworkState.checking:
        return Icons.sync;
      case NetworkState.unknown:
        return Icons.help_outline;
    }
  }
  
  @override
  Widget buildActionButton(VoidCallback onPressed) {
    switch (this) {
      case NetworkState.online:
        return ElevatedButton.icon(
          icon: Icon(Icons.refresh),
          label: Text('再読み込み'),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        );
      case NetworkState.offline:
        return ElevatedButton.icon(
          icon: Icon(Icons.settings),
          label: Text('ネットワーク設定'),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        );
      case NetworkState.serverDown:
        return ElevatedButton.icon(
          icon: Icon(Icons.replay),
          label: Text('再試行'),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        );
      case NetworkState.checking:
        return ElevatedButton(
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 8),
              Text('確認中...'),
            ],
          ),
        );
      case NetworkState.unknown:
        return ElevatedButton.icon(
          icon: Icon(Icons.refresh),
          label: Text('状態確認'),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        );
    }
  }
}

// 接続タイプを表すenum
enum ConnectionType {
  wifi,
  mobile,
  ethernet,
  bluetooth,
  none,
  unknown;
  
  // ConnectivityResultから変換するファクトリメソッド
  factory ConnectionType.fromConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return ConnectionType.wifi;
      case ConnectivityResult.mobile:
        return ConnectionType.mobile;
      case ConnectivityResult.ethernet:
        return ConnectionType.ethernet;
      case ConnectivityResult.bluetooth:
        return ConnectionType.bluetooth;
      case ConnectivityResult.none:
        return ConnectionType.none;
      default:
        return ConnectionType.unknown;
    }
  }
  
  // 接続タイプに応じたアイコンを取得
  IconData get icon {
    switch (this) {
      case ConnectionType.wifi:
        return Icons.wifi;
      case ConnectionType.mobile:
        return Icons.signal_cellular_4_bar;
      case ConnectionType.ethernet:
        return Icons.settings_ethernet;
      case ConnectionType.bluetooth:
        return Icons.bluetooth;
      case ConnectionType.none:
        return Icons.signal_wifi_off;
      case ConnectionType.unknown:
        return Icons.device_unknown;
    }
  }
  
  // 接続タイプの日本語名を取得
  String get displayName {
    switch (this) {
      case ConnectionType.wifi:
        return 'Wi-Fi';
      case ConnectionType.mobile:
        return 'モバイルデータ';
      case ConnectionType.ethernet:
        return '有線接続';
      case ConnectionType.bluetooth:
        return 'Bluetooth';
      case ConnectionType.none:
        return '接続なし';
      case ConnectionType.unknown:
        return '不明な接続';
    }
  }
}

// ネットワーク状態を監視し管理するクラス
class NetworkStateManager {
  final Connectivity _connectivity = Connectivity();
  final String _healthCheckUrl;
  
  // シングルトンパターンの実装
  static NetworkStateManager? _instance;
  factory NetworkStateManager({String healthCheckUrl = 'https://www.google.com'}) {
    _instance ??= NetworkStateManager._internal(healthCheckUrl);
    return _instance!;
  }
  
  NetworkStateManager._internal(this._healthCheckUrl);
  
  // 現在のネットワーク状態
  NetworkState _currentState = NetworkState.unknown;
  NetworkState get currentState => _currentState;
  
  // 現在の接続タイプ
  ConnectionType _connectionType = ConnectionType.unknown;
  ConnectionType get connectionType => _connectionType;
  
  // 状態変化を通知するためのStreamController
  final _stateController = StreamController<NetworkState>.broadcast();
  Stream<NetworkState> get stateStream => _stateController.stream;
  
  // 通信の健全性をチェックする間隔（秒）
  final Duration _healthCheckInterval = Duration(seconds: 30);
  Timer? _healthCheckTimer;
  StreamSubscription? _connectivitySubscription;
  
  // 初期化処理
  Future<void> initialize() async {
    // 初期状態のチェック
    await _checkConnectivity();
    
    // 既存のサブスクリプションをキャンセル
    _connectivitySubscription?.cancel();
    
    // 接続状態の変化を監視
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      debugPrint('接続状態の変化: $result');
      
      if (result.isEmpty || result.contains(ConnectivityResult.none)) {
        _connectionType = ConnectionType.none;
        _updateState(NetworkState.offline);
      } else {
        // 接続タイプを更新
        if (result.contains(ConnectivityResult.wifi)) {
          _connectionType = ConnectionType.wifi;
        } else if (result.contains(ConnectivityResult.mobile)) {
          _connectionType = ConnectionType.mobile;
        } else if (result.contains(ConnectivityResult.ethernet)) {
          _connectionType = ConnectionType.ethernet;
        } else if (result.contains(ConnectivityResult.bluetooth)) {
          _connectionType = ConnectionType.bluetooth;
        } else {
          _connectionType = ConnectionType.unknown;
        }
        
        // 接続はあるが、サーバーの状態を確認する必要がある
        _updateState(NetworkState.checking);
        _checkServerHealth();
      }
    });
    
    // 定期的なヘルスチェック
    _startPeriodicHealthCheck();
  }
  
  // 接続状態を確認
  Future<void> _checkConnectivity() async {
    _updateState(NetworkState.checking);
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) {
        _connectionType = ConnectionType.none;
        _updateState(NetworkState.offline);
      } else {
        // 接続タイプを更新
        if (connectivityResult.contains(ConnectivityResult.wifi)) {
          _connectionType = ConnectionType.wifi;
        } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
          _connectionType = ConnectionType.mobile;
        } else if (connectivityResult.contains(ConnectivityResult.ethernet)) {
          _connectionType = ConnectionType.ethernet;
        } else if (connectivityResult.contains(ConnectivityResult.bluetooth)) {
          _connectionType = ConnectionType.bluetooth;
        } else {
          _connectionType = ConnectionType.unknown;
        }
        
        await _checkServerHealth();
      }
    } catch (e) {
      _updateState(NetworkState.unknown);
      currentState.log('接続確認中にエラーが発生しました: $e');
    }
  }
  
  // サーバーの健全性を確認
  Future<void> _checkServerHealth() async {
    if (_connectionType == ConnectionType.none) {
      _updateState(NetworkState.offline);
      return;
    }
    
    try {
      // タイムアウトを5秒に設定
      final response = await http.get(Uri.parse(_healthCheckUrl))
          .timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        _updateState(NetworkState.online);
      } else {
        _updateState(NetworkState.serverDown);
        currentState.log('サーバーから異常なレスポンスを受信: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      _updateState(NetworkState.serverDown);
      currentState.log('サーバー接続エラー: $e');
    } on TimeoutException catch (e) {
      _updateState(NetworkState.serverDown);
      currentState.log('サーバー接続タイムアウト: $e');
    } catch (e) {
      _updateState(NetworkState.unknown);
      currentState.log('健全性チェック中にエラーが発生: $e');
    }
  }
  
  // 定期的なヘルスチェックを開始
  void _startPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      _checkConnectivity();
    });
  }
  
  // ネットワーク状態を手動で確認
  Future<void> checkNetworkState() async {
    debugPrint('手動でネットワーク状態をチェックします');
    await _checkConnectivity();
  }
  
  // 状態を更新
  void _updateState(NetworkState newState) {
    if (_currentState != newState) {
      debugPrint('ネットワーク状態の更新: $_currentState → $newState');
      _currentState = newState;
      _stateController.add(newState);
      newState.log('ネットワーク状態が変更されました');
    }
  }
  
  // リソースの解放
  void dispose() {
    _healthCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    _stateController.close();
  }
}

// ネットワーク状態表示用のウィジェット
class NetworkStatusWidget extends StatefulWidget {
  final Widget? child;
  final String healthCheckUrl;
  
  const NetworkStatusWidget({
    super.key,
    this.child,
    this.healthCheckUrl = 'https://www.google.com',
  });

  @override
  _NetworkStatusWidgetState createState() => _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends State<NetworkStatusWidget> {
  late NetworkStateManager _networkManager;
  
  @override
  void initState() {
    super.initState();
    _networkManager = NetworkStateManager(healthCheckUrl: widget.healthCheckUrl);
    
    // Ensure we initialize the network manager properly when the widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _networkManager.initialize();
      // Force an immediate check of network state when widget initializes
      _networkManager.checkNetworkState();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkState>(
      stream: _networkManager.stateStream,
      initialData: _networkManager.currentState,
      builder: (context, snapshot) {
        final networkState = snapshot.data ?? NetworkState.unknown;
        debugPrint('NetworkStatusWidget rebuilding with state: $networkState');
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ネットワークステータスバー
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: networkState.statusColor.withValues(alpha: 0.2),
              child: Row(
                children: [
                  Icon(
                    networkState.statusIcon,
                    color: networkState.statusColor,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      networkState.statusMessage,
                      style: TextStyle(
                        color: networkState.statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_networkManager.connectionType != ConnectionType.none)
                    Row(
                      children: [
                        Icon(
                          _networkManager.connectionType.icon,
                          size: 16,
                          color: networkState.statusColor,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _networkManager.connectionType.displayName,
                          style: TextStyle(
                            color: networkState.statusColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            
            // アクションボタン（必要に応じて）
            if (networkState != NetworkState.online)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: networkState.buildActionButton(() {
                  _networkManager.checkNetworkState();
                }),
              ),
            
            // 子ウィジェット
            if (widget.child != null)
              Expanded(child: widget.child!),
          ],
        );
      },
    );
  }
  
  @override
  void dispose() {
    // For completeness, we should clean up if this widget is disposed
    // Even though the manager is a singleton, we could have per-widget settings
    super.dispose();
  }
}

// ネットワーク状態に応じてコンテンツを条件付きで表示するウィジェット
class NetworkAwareWidget extends StatefulWidget {
  final Widget onlineChild;
  final Widget? offlineChild;
  final Widget? serverDownChild;
  final Widget? loadingChild;
  final String healthCheckUrl;
  
  const NetworkAwareWidget({
    super.key,
    required this.onlineChild,
    this.offlineChild,
    this.serverDownChild,
    this.loadingChild,
    this.healthCheckUrl = 'https://www.google.com',
  });

  @override
  _NetworkAwareWidgetState createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  late NetworkStateManager _networkManager;
  
  @override
  void initState() {
    super.initState();
    _networkManager = NetworkStateManager(healthCheckUrl: widget.healthCheckUrl);
    
    // Make sure initialization happens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _networkManager.initialize();
      // Force check of network state
      _networkManager.checkNetworkState();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkState>(
      stream: _networkManager.stateStream,
      initialData: _networkManager.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? NetworkState.unknown;
        debugPrint('NetworkAwareWidget building with state: $state');
        
        switch (state) {
          case NetworkState.online:
            return widget.onlineChild;
          case NetworkState.offline:
            return widget.offlineChild ?? _buildDefaultWidget(
              '現在オフラインです',
              'インターネット接続を確認してください',
              Icons.wifi_off,
              Colors.red,
            );
          case NetworkState.serverDown:
            return widget.serverDownChild ?? _buildDefaultWidget(
              'サーバーに接続できません',
              'しばらくしてから再度お試しください',
              Icons.cloud_off,
              Colors.orange,
            );
          case NetworkState.checking:
            return widget.loadingChild ?? _buildLoadingWidget();
          case NetworkState.unknown:
            return _buildDefaultWidget(
              '接続状態が不明です',
              '接続を確認しています',
              Icons.help_outline,
              Colors.grey,
            );
        }
      },
    );
  }
  
  Widget _buildDefaultWidget(String title, String message, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: color,
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              NetworkStateManager().checkNetworkState();
            },
            child: Text('再試行'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('接続状態を確認中...'),
        ],
      ),
    );
  }
}

// 使用例
class ExampleNetworkStateApp extends StatelessWidget {
  const ExampleNetworkStateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ネットワーク状態管理デモ',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('ネットワーク状態管理'),
        ),
        body: NetworkStatusWidget(
          healthCheckUrl: 'https://api.example.com/health', // 実際のAPIエンドポイントに変更
          child: NetworkAwareWidget(
            onlineChild: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'オンライン状態です',
                    style: TextStyle(fontSize: 20),
                  ),
                  SizedBox(height: 8),
                  Text('すべての機能が利用可能です'),
                ],
              ),
            ),
            // 他の状態用のウィジェットはデフォルトを使用
          ),
        ),
      ),
    );
  }
}
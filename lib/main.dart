import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:string_extensions/string_extensions.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io' as io;

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<String>? _setupSubscription;
  StreamSubscription<BluetoothState>? _bluetoothStateSubscription;
  MidiCommand _midiCommand = MidiCommand();

  String _chooseYourCharacter = "andy";

  String _currentPage =
      io.Platform.isAndroid || io.Platform.isIOS ? "pdf" : "midi";
  int _numberOfFilesDownloaded = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  bool _virtualDeviceActivated = false;
  Map<String, dynamic> accountsFullNames = {"andy": ""};
  Map<String, dynamic> accountsImagePaths = {"andy": "assets/andy-face.png"};
  Map<String, dynamic> accountsPdfUrls = {"andy": List.filled(35, "")};

  String remotePDFpath = "";
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<String> loadJsonData() async {
    var fullNames =
        await rootBundle.loadString('assets/accountsFullNames.json');
    var imagePaths =
        await rootBundle.loadString('assets/accountsImagePaths.json');
    var pdfUrls = await rootBundle.loadString('assets/accountsPdfUrls.json');

    setState(() {
      accountsFullNames = json.decode(fullNames);
      accountsImagePaths = json.decode(imagePaths);
      accountsPdfUrls = json.decode(pdfUrls);
    });

    _prefs.then((SharedPreferences prefs) {
      accountsImagePaths.keys.forEach((account) {
        var localFilenames = prefs.getString("localFilenames:${account}");
        if (localFilenames == null) {
          List<String> emptyArrayFilled = List.filled(35, "");
          prefs.setString(
              'localFilenames:${account}', jsonEncode(emptyArrayFilled));
        }
      });
    });
    return 'success';
  }

  @override
  initState() {
    _prefs.then((SharedPreferences prefs) {
      var savedUser = prefs.getString("savedUser");
      if (savedUser == null) {
        savedUser = "andy";
        prefs.setString("savedUser", "andy");
      } else {
        _chooseYourCharacter = savedUser;
      }
      var localFilenames = prefs.getString("localFilenames:${savedUser}");
      if (localFilenames == null) {
        List<String> emptyArrayFilled = List.filled(35, "");
        prefs.setString(
            'localFilenames:${savedUser}', jsonEncode(emptyArrayFilled));
      }
      changeSong(1);
    });
    changeSong(1);

    super.initState();

    this.loadJsonData();

    _setupSubscription = _midiCommand.onMidiSetupChanged?.listen((data) async {
      print("setup changed $data");
      setState(() {});
    });

    _bluetoothStateSubscription =
        _midiCommand.onBluetoothStateChanged.listen((data) {
      print("bluetooth state change $data");
      setState(() {});
    });

    //await _informUserAboutBluetoothPermissions(context);
    //await _midiCommand.startBluetoothCentral();
    //await _midiCommand.waitUntilBluetoothIsInitialized();
    _midiCommand.devices.then((devices) {
      print('here are all them devices ${devices![0]}');
      MidiDevice device = devices[0];
      if (!device.connected) {
        _midiCommand.connectToDevice(device);
      }
    });
    updateNumberOfFiles();
/*
    createFileOfPdfUrl("").then((f) {
      setState(() {
        remotePDFpath = f.path;
      });
    });
    */
  }

  void downloadAllSongs() async {
    if (_numberOfFilesDownloaded == 0) {
      await Future.wait((accountsPdfUrls[_chooseYourCharacter] as List)
              .mapIndexed((i, url) async {
        createFileOfPdfUrl(url).then((f) {
          var filename = f.path.substring(f.path.lastIndexOf("/") + 1);
          _prefs.then((SharedPreferences prefs) {
            var localFilenames = jsonDecode(
                prefs.getString("localFilenames:${_chooseYourCharacter}") ??
                    "");
            localFilenames[i] = filename;
            prefs.setString('localFilenames:${_chooseYourCharacter}',
                jsonEncode(localFilenames));
          });
        });
      }).toList())
          .then((value) {
        //updateNumberOfFiles();
      });
    }
  }

  void updateNumberOfFiles() async {
    var directory = await getApplicationDocumentsDirectory();
    var whereAllFilesAreStored = directory.path;
    final dir = io.Directory(whereAllFilesAreStored);
    var all = dir.listSync();
    print(all);
    setState(() {
      _numberOfFilesDownloaded = all.length;
    });
  }

  void changeSong(index) {
    print("changed");
    print(index);

    _prefs.then((SharedPreferences prefs) async {
      print("person is ${_chooseYourCharacter}");
      var localFilenames = jsonDecode(
          prefs.getString("localFilenames:${_chooseYourCharacter}") ?? "");
      print("localfilenames: ${localFilenames}");
      var dir = await getApplicationDocumentsDirectory();
      var filename = localFilenames[index];
      setState(() {
        if (filename == "") {
          remotePDFpath = '';
        } else {
          remotePDFpath = '${dir.path}/${filename}';
        }
      });
    });
  }

  Future<io.File> createFileOfPdfUrl(url) async {
    Completer<io.File> completer = Completer();

    print("Start download file from internet!");
    print(url);
    //try {
    // "https://berlin2017.droidcon.cod.newthinking.net/sites/global.droidcon.cod.newthinking.net/files/media/documents/Flutter%20-%2060FPS%20UI%20of%20the%20future%20%20-%20DroidconDE%2017.pdf";
    //final url = "https://pdfkit.org/docs/guide.pdf";
    //final url =
    //    "https://vgleadsheets.com/assets/sheets/C/Banjo-Kazooie%20-%20Gruntilda's%20Lair.pdf";
    //final url =
    //"https://raw.githubusercontent.com/abandonquestband/aq-learning-center/main/sheet-music/dance-dance-revolution_xephyr/dance-dance-revolution_xephyr-Piano.pdf?token=GHSAT0AAAAAABRE3ZWMY5GKS63FWY2TVFT6YRICI4A";
    final filename = url.substring(url.lastIndexOf("/") + 1);
    var request = await io.HttpClient().getUrl(Uri.parse(url));
    var response = await request.close();
    var bytes = await consolidateHttpClientResponseBytes(response);
    var dir = await getApplicationDocumentsDirectory();
    print(dir.listSync(recursive: true));
    print("Download files");
    debugPrint("DOWNLODINAG");
    print("${dir.path}/$filename");
    io.File file = io.File("${dir.path}/$filename");

    await file.writeAsBytes(bytes, flush: true);
    completer.complete(file);
    //} catch (e) {
    //throw Exception('Error parsing asset file!');
    //}
    return completer.future;
    //return completer.future;
  }

  Future<io.File> fromAsset(String asset, String filename) async {
    // To open from assets, you can copy them to the app storage folder, and the access them "locally"
    Completer<io.File> completer = Completer();

    try {
      var dir = await getApplicationDocumentsDirectory();
      io.File file = io.File("${dir.path}/$filename");
      var data = await rootBundle.load(asset);
      var bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes, flush: true);
      completer.complete(file);
    } catch (e) {
      throw Exception('Error parsing asset file!');
    }
    return completer.future;
  }

  @override
  void dispose() {
    _setupSubscription?.cancel();
    _bluetoothStateSubscription?.cancel();
    super.dispose();
  }

  IconData _deviceIconForType(String type) {
    switch (type) {
      case "native":
        return Icons.devices;
      case "network":
        return Icons.language;
      case "BLE":
        return Icons.bluetooth;
      default:
        return Icons.device_unknown;
    }
  }

  Future<void> _informUserAboutBluetoothPermissions(
      BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
              'Please Grant Bluetooth Permissions to discover BLE MIDI Devices.'),
          content: const Text(
              'In the next dialog we might ask you for bluetooth permissions.\n'
              'Please grant permissions to make bluetooth MIDI possible.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Ok. I got it!'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    return;
  }

  @override
  Widget build(BuildContext context) {
    String username = _chooseYourCharacter;
    var drawerHeader = UserAccountsDrawerHeader(
      decoration: BoxDecoration(
        color: Color.fromRGBO(152, 56, 148, 1),
      ),
      accountName: Text(accountsFullNames[_chooseYourCharacter] ?? ""),
      accountEmail: Text('Abandon Quest'),
      currentAccountPicture: CircleAvatar(
        backgroundImage:
            AssetImage("assets/images/${_chooseYourCharacter}-face.png"),
      ),
      otherAccountsPictures: <Widget>[
        ...accountsImagePaths.keys
            .where((name) => name != _chooseYourCharacter)
            .map((person) => GestureDetector(
                  onTap: () {
                    _prefs.then((SharedPreferences prefs) {
                      prefs.setString('savedUser', person);
                    });
                    setState(() {
                      _chooseYourCharacter = person;
                      changeSong(1);
                    });
                  },
                  child: CircleAvatar(
                    backgroundImage:
                        AssetImage("assets/images/${person}-face.png"),
                  ),
                ))
      ],
    );
    var drawerItems = ListView(
      key: ValueKey<int>(_numberOfFilesDownloaded),
      padding: EdgeInsets.zero,
      children: <Widget>[
        drawerHeader,
        OutlinedButton.icon(
          onPressed: () {
            // Respond to button press
            setState(() {
              _scaffoldKey.currentState!.openDrawer();
              //Navigator.of(context).pop();
              _currentPage = "midi";
            });
          },
          icon: Icon(Icons.wifi, size: 18),
          label: Text("MIDI Network Settings"),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            // Respond to button press
            downloadAllSongs();
          },
          icon: Icon(Icons.download, size: 18),
          label: Text("Download ${_chooseYourCharacter.capitalize}'s PDFs"),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            updateNumberOfFiles();
          },
          icon: Icon(Icons.refresh, size: 18),
          label: Text("Refresh ${_chooseYourCharacter.capitalize}'s PDF Count"),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            setState(() {
              remotePDFpath = "";
            });
            // Respond to button press
            final directory = await getApplicationDocumentsDirectory();
            var whereAllFilesAreStored = directory.path;
            final dir = io.Directory(whereAllFilesAreStored);
            var all = dir.listSync();
            all.forEach((file) {
              io.File(file.path).deleteSync();
            });
            _prefs.then((SharedPreferences prefs) {
              List<String> emptyArrayFilled = List.filled(35, "");
              accountsImagePaths.keys.forEach((element) {
                prefs.remove(element);
              });
              updateNumberOfFiles();
            });
          },
          icon: Icon(Icons.delete_forever, size: 18),
          label: Text("Delete All Downloaded PDFs"),
        ),
        ...List<Widget>.generate(
          (accountsPdfUrls[_chooseYourCharacter] ?? [] as List).length,
          (i) => ListTile(
              title: Text(
                  "${(accountsPdfUrls[_chooseYourCharacter]![i].substring(accountsPdfUrls[_chooseYourCharacter]![i].lastIndexOf("/") + 1).replaceAll("%20", " ").replaceAll(".pdf", "").replaceAll(" - ", ": ").replaceAll("-", " ").replaceAll("_", ": ") as String).toUpperCase()}"),
              onTap: () {
                changeSong(i);
              }),
        ),
      ],
    );

    return new MaterialApp(
        color: Colors.blue,
        home: SafeArea(
          top: true,
          child: new Scaffold(
            key: _scaffoldKey,
            floatingActionButtonLocation: _currentPage == "pdf"
                ? FloatingActionButtonLocation.startFloat
                : FloatingActionButtonLocation.endFloat,
            floatingActionButton: false
                ? null
                : FloatingActionButton(
                    focusColor: Color.fromRGBO(152, 56, 148, 0),
                    hoverColor: Color.fromRGBO(152, 56, 148, 0),
                    splashColor: Color.fromRGBO(152, 56, 148, 0),
                    backgroundColor: Color.fromRGBO(152, 56, 148, 1),
                    child: _currentPage == "pdf"
                        ? Icon(Icons.music_note, size: 42)
                        : Icon(Icons.picture_as_pdf, size: 42),
                    onPressed: () {
                      switch (_currentPage) {
                        case "pdf":
                          _scaffoldKey.currentState!.openEndDrawer();
                          break;
                        case "midi":
                          setState(() {
                            _currentPage = "pdf";
                          });
                          break;
                      }
                      ;
                    }),
            endDrawer: Drawer(
              child: drawerItems,
            ),
            appBar: _currentPage == "pdf"
                ? null
                : new AppBar(
                    backgroundColor: Color.fromRGBO(152, 56, 148, 1),
                    title:
                        Text('Connect to AQ PDF Switcher and your Page Turner'),
                    actions: <Widget>[
                      Builder(builder: (context) {
                        return IconButton(
                            onPressed: () async {
                              // Ask for bluetooth permissions
                              await _informUserAboutBluetoothPermissions(
                                  context);

                              // Start bluetooth
                              await _midiCommand.startBluetoothCentral();

                              await _midiCommand
                                  .waitUntilBluetoothIsInitialized();

                              // If bluetooth is powered on, start scanning
                              if (_midiCommand.bluetoothState ==
                                  BluetoothState.poweredOn) {
                                _midiCommand
                                    .startScanningForBluetoothDevices()
                                    .catchError((err) {
                                  print("Error $err");
                                });

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      'Scanning for bluetooth devices ...'),
                                ));
                              } else {
                                final messages = {
                                  BluetoothState.unsupported:
                                      'Bluetooth is not supported on this device.',
                                  BluetoothState.poweredOff:
                                      'Please switch on bluetooth and try again.',
                                  BluetoothState.poweredOn:
                                      'Everything is fine.',
                                  BluetoothState.resetting:
                                      'Currently resetting. Try again later.',
                                  BluetoothState.unauthorized:
                                      'This app needs bluetooth permissions. Please open settings, find your app and assign bluetooth access rights and start your app again.',
                                  BluetoothState.unknown:
                                      'Bluetooth is not ready yet. Try again later.',
                                  BluetoothState.other:
                                      'This should never happen. Please inform the developer of your app.',
                                };

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text(messages[
                                          _midiCommand.bluetoothState] ??
                                      'Unknown bluetooth state: ${_midiCommand.bluetoothState}'),
                                ));
                              }

                              // If not show a message telling users what to do
                              setState(() {});
                            },
                            icon: Icon(Icons.refresh));
                      }),
                      /*
                      Builder(builder: (context) {
                        return IconButton(
                            onPressed: () async {
                              final directory =
                                  await getApplicationDocumentsDirectory();
                              var whereAllFilesAreStored = directory.path;
                              final dir = io.Directory(whereAllFilesAreStored);
                              var all = dir.listSync();
                              print(all);
                              setState(() {
                                _numberOfFilesDownloaded = all.length;
                              });
                            },
                            icon: Icon(Icons.list));
                      }),
                      Builder(builder: (context) {
                        return IconButton(
                            onPressed: () async {
                              _prefs.then((SharedPreferences prefs) {
                                var localFilenames = jsonDecode(
                                    prefs.getString("localFilenames") ?? "");
                                print('localFilenames: ${localFilenames}');
                              });
                            },
                            icon: Icon(Icons.storage));
                      }),
                      */
                    ],
                  ),
            /*
        bottomNavigationBar: Container(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "Choose a MIDI device to connect to (Probably \"Network Session\")",
            textAlign: TextAlign.center,
          ),
        ),
        */
            body: Center(
              child: FutureBuilder(
                future: _midiCommand.devices,
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    var devices = (snapshot.data as List<MidiDevice>);
                    devices.sort((a, b) {
                      return a.name
                          .toLowerCase()
                          .compareTo(b.name.toLowerCase());
                    });
                    //devices.removeWhere(
                    //  (element) => !element.name.contains("Jamstik"));
                    // var devices =
                    //     allDevices.where((d) => d.name.contains('Jamstik'))
                    //         as List<MidiDevice>;
                    /*
                var devices = (snapshot.data as List<MidiDevice>);
                MidiDevice device = devices[index];
                _midiCommand.connectToDevice(device);
                */
                    switch (_currentPage) {
                      case "pdf":
                        return ControllerPage(remotePDFpath, changeSong);
                      case "midi":
                      default:
                        return ListView.builder(
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            MidiDevice device = devices[index];
                            return ListTile(
                              title: Text(
                                device.name,
                                style: Theme.of(context).textTheme.headline5,
                              ),
                              subtitle: Text(
                                  "ins:${device.inputPorts.length} outs:${device.outputPorts.length}"),
                              leading: Icon(device.connected
                                  ? Icons.radio_button_on
                                  : Icons.radio_button_off),
                              trailing: Icon(_deviceIconForType(device.type)),
                              onLongPress: () {},
                              onTap: () {
                                if (device.connected) {
                                  _midiCommand.disconnectDevice(device);
                                } else {
                                  print("connect");
                                  _midiCommand
                                      .connectToDevice(device)
                                      .then((_) {
                                    print("device connected async");
                                  });
                                }
                              },
                            );
                          },
                        );
                    }
                  } else {
                    return new CircularProgressIndicator();
                  }
                },
              ),
            ),
          ),
        ));
  }
}

class _NewPage extends MaterialPageRoute<void> {
  _NewPage(int id)
      : super(
          builder: (BuildContext context) {
            return Scaffold(
              appBar: AppBar(
                title: Text('Page $id'),
                elevation: 1.0,
              ),
              body: Center(
                child: Text('Page $id'),
              ),
            );
          },
        );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io' show Platform, File;

int mutableCurrentPage = 0;

class ControllerPage extends StatelessWidget {
  String remotePDFpath;
  Function changeSong;

  ControllerPage(this.remotePDFpath, this.changeSong);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*
      appBar: AppBar(
        title: Text(remotePDFpath
            .substring(remotePDFpath.lastIndexOf("/") + 1)
            .replaceAll("%20", " ")),
      ),
      */
      key: ValueKey<String>(remotePDFpath),
      body: MidiControls(remotePDFpath, changeSong),
    );
  }
}

class MidiControls extends StatefulWidget {
  String remotePDFpath;
  Function changeSong;

  MidiControls(this.remotePDFpath, this.changeSong);

  @override
  MidiControlsState createState() {
    return new MidiControlsState();
  }
}

class MidiControlsState extends State<MidiControls> {
  var _channel = 0;
  var _controller = 0;
  var _value = 0;
  int? pages = 0;
  int _totalNumberOfPages = 1;
  int? currentPage = 0;
  bool isReady = false;
  String errorMessage = '';
  late PDFViewController _pdfViewController;
  late PdfViewerController _pdfViewerController;
  StreamSubscription<MidiPacket>? _rxSubscription;
  MidiCommand _midiCommand = MidiCommand();

  @override
  void initState() {
    _pdfViewerController = PdfViewerController();
    _rxSubscription =
        _midiCommand.onMidiDataReceived?.listen(handleMidiPackets);

    super.initState();
  }

  void handleMidiData(data) async {
    //print('handleMidiData: ${data}');
    if (data[0] == 192 && data.length > 1) {
      if (Platform.isMacOS) {
        _pdfViewerController.jumpToPage(data[1] + 1);
      } else {
        _pdfViewController.setPage(data[1]);
      }
      int newState = data[1]; //Platform.isMacOS ? data[1] + 1 : data[1];
      mutableCurrentPage = Platform.isMacOS ? data[1] + 1 : data[1];
      ;
      setState(() {
        currentPage = newState;
      });
    }
    if (data[0] == 176 && data[1] == 0 && data.length > 2) {
      widget.changeSong(data[2]);
    }
  }

  void handleMidiPackets(packet) {
    var data = packet.data;
    //var timestamp = packet.timestamp;
    //var device = packet.device;
    //print(
    //    "data $data @ time $timestamp from device ${device.name}:${device.id}");
    //var status = data[0];

    List<int> midiPacket = <int>[...data];
    var i = 0;

    var bufferOfGroups = [];
    var buffer = [];
    while (i < midiPacket.length) {
      if (midiPacket[i] == 176 || midiPacket[i] == 192) {
        //check to see how big buffer is currently
        while (buffer.length < 3) {
          buffer.add(0);
        }
        bufferOfGroups.add(buffer);
        buffer = [];
        buffer.add(midiPacket[i]);
      } else {
        buffer.add(midiPacket[i]);
        if (buffer.length == 3) {
          bufferOfGroups.add(buffer);
          buffer = [];
        }
      }
      i++;
    }
    if (buffer.length != 0) {
      while (buffer.length < 3) {
        buffer.add(0);
      }
      bufferOfGroups.add(buffer);
      buffer = [];
    }
    bufferOfGroups.forEach((message) {
      handleMidiData(message);
    });
  }

  void dispose() {
    // _setupSubscription?.cancel();
    _rxSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.remotePDFpath == "" ||
        !File(widget.remotePDFpath).existsSync()) {
      return Scaffold(
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset("assets/images/aq_logo-transparent.png"),
            Text(
              "Click the music note to get started!",
              style: TextStyle(fontSize: 25),
              textAlign: TextAlign.center,
            )
          ],
        )),
      );
    }
    if (Platform.isMacOS) {
      return Scaffold(
          body: Stack(
        children: <Widget>[
          SfPdfViewer.file(
            File(widget.remotePDFpath),
            enableDoubleTapZooming: false,
            controller: _pdfViewerController,
            onDocumentLoaded: (details) {
              setState(() {
                _totalNumberOfPages = details.document.pages.count;
              });
              _pdfViewerController.jumpToPage(mutableCurrentPage);
            },
            scrollDirection: PdfScrollDirection.horizontal,
            pageLayoutMode: PdfPageLayoutMode.single,
            canShowPaginationDialog: false,
            interactionMode: PdfInteractionMode.pan,
            canShowScrollHead: false,
            canShowScrollStatus: false,
          ),
          Positioned(
              child: _totalNumberOfPages == 1
                  ? SizedBox.shrink()
                  : Slider(
                      value: currentPage! + .0,
                      min: 0,
                      max: _totalNumberOfPages - 1.0,
                      divisions: _totalNumberOfPages - 1,
                      thumbColor: Color.fromRGBO(152, 56, 148, 1),
                      activeColor: Color.fromRGBO(152, 56, 148, 1),
                      inactiveColor: Color.fromRGBO(152, 56, 148, .5),
                      label: (currentPage! + 1).toString(),
                      onChanged: (double value) {
                        setState(() {
                          currentPage = value.round();
                        });
                        if (Platform.isMacOS) {
                          _pdfViewerController.jumpToPage(value.round() + 1);
                        }
                        if (Platform.isIOS) {
                          _pdfViewController.setPage(value.round());
                        }
                      },
                    ),
              bottom: 5),
          Positioned(
              child: Text("${currentPage! + 1}/${_totalNumberOfPages}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                      color: Color.fromRGBO(152, 56, 148, .5))),
              left: 15,
              top: 15),
          Positioned(
              child: Text("${currentPage! + 1}/${_totalNumberOfPages}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                      color: Color.fromRGBO(152, 56, 148, .5))),
              bottom: 15,
              right: 15)
        ],
        alignment: Alignment.center,
      ));
    }
    return Scaffold(
      body: Stack(
        children: [
          Builder(builder: (context) {
            return Platform.isIOS || Platform.isAndroid
                ? SizedBox(
                    /*
                  850x1200, 800x1000, 
                  */
                    width: 850,
                    height: 1200,
                    child: PDFView(
                      key: ValueKey<String>(widget.remotePDFpath),
                      filePath: widget.remotePDFpath,
                      enableSwipe: true,
                      swipeHorizontal: true,
                      autoSpacing: true,
                      pageFling: true,
                      pageSnap: true,
                      defaultPage: currentPage!,
                      fitPolicy: FitPolicy.BOTH,
                      preventLinkNavigation:
                          false, // if set to true the link is handled in flutter
                      onRender: (_pages) {
                        setState(() {
                          pages = _pages;
                          isReady = true;
                        });
                      },
                      onError: (error) {
                        setState(() {
                          errorMessage = error.toString();
                        });
                        print(error.toString());
                      },
                      onPageError: (page, error) {
                        setState(() {
                          errorMessage = '$page: ${error.toString()}';
                        });
                        print('$page: ${error.toString()}');
                      },
                      onViewCreated: (PDFViewController vc) {
                        vc.getPageCount().then((pageCount) {
                          setState(() {
                            _pdfViewController = vc;
                            _totalNumberOfPages = pageCount!;
                          });
                        });
                      },
                      onLinkHandler: (String? uri) {
                        print('goto uri: $uri');
                      },
                      onPageChanged: (int? page, int? total) {
                        print('page change: $page/$total');
                        setState(() {
                          currentPage = page;
                        });
                      },
                    ),
                  )
                : SizedBox(
                    width: 50,
                    height:
                        30, /*
                    child: PdfController(
                            document:
                                PdfDocument.openFile(widget.remotePDFpath)),
                  */
                  );
          }),
          Positioned(
              child: _totalNumberOfPages == 1
                  ? SizedBox.shrink()
                  : Slider(
                      value: currentPage! + .0,
                      min: 0,
                      max: _totalNumberOfPages - 1.0,
                      divisions: _totalNumberOfPages - 1,
                      thumbColor: Color.fromRGBO(152, 56, 148, 1),
                      activeColor: Color.fromRGBO(152, 56, 148, 1),
                      inactiveColor: Color.fromRGBO(152, 56, 148, .5),
                      label: (currentPage! + 1).toString(),
                      onChanged: (double value) {
                        setState(() {
                          currentPage = value.round();
                        });
                        if (Platform.isMacOS) {
                          _pdfViewerController.jumpToPage(value.round() + 1);
                        }
                        if (Platform.isIOS) {
                          _pdfViewController.setPage(value.round());
                        }
                      },
                    ),
              bottom: 5),
          Positioned(
              child: Text("${currentPage! + 1}/${_totalNumberOfPages}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                      color: Color.fromRGBO(152, 56, 148, .5))),
              right: 15,
              bottom: 15),
          Positioned(
              child: Text("${currentPage! + 1}/${_totalNumberOfPages}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                      color: Color.fromRGBO(152, 56, 148, .5))),
              left: 15,
              top: 15)
        ],
        alignment: Alignment.center,
      )
      //SteppedSelector('Channel', _channel + 1, 1, 16, _onChannelChanged),
      //SteppedSelector(
      //    'Controller', _controller, 0, 127, _onControllerChanged),
      //SlidingSelector('Value', _value, 0, 127, _onValueChanged),
      ,
    );
  }

  _onChannelChanged(int newValue) {
    setState(() {
      _channel = newValue - 1;
    });
  }

  _onControllerChanged(int newValue) {
    setState(() {
      _controller = newValue;
    });
  }

  _onValueChanged(int newValue) {
    setState(() {
      _value = newValue;
      CCMessage(channel: _channel, controller: _controller, value: _value)
          .send();
    });
  }
}

class SteppedSelector extends StatelessWidget {
  final String label;
  final int minValue;
  final int maxValue;
  final int value;
  final Function(int) callback;

  SteppedSelector(
      this.label, this.value, this.minValue, this.maxValue, this.callback);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(label),
        IconButton(
            icon: Icon(Icons.remove_circle),
            onPressed: (value > minValue)
                ? () {
                    callback(value - 1);
                  }
                : null),
        Text(value.toString()),
        IconButton(
            icon: Icon(Icons.add_circle),
            onPressed: (value < maxValue)
                ? () {
                    callback(value + 1);
                  }
                : null)
      ],
    );
  }
}

class SlidingSelector extends StatelessWidget {
  final String label;
  final int minValue;
  final int maxValue;
  final int value;
  final Function(int) callback;

  SlidingSelector(
      this.label, this.value, this.minValue, this.maxValue, this.callback);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(label),
        Slider(
          value: value.toDouble(),
          divisions: maxValue,
          min: minValue.toDouble(),
          max: maxValue.toDouble(),
          onChanged: (v) {
            callback(v.toInt());
          },
        ),
        Text(value.toString()),
      ],
    );
  }
}

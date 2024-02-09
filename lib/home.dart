import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:stevebot/progress.dart';
import 'package:uuid/uuid.dart';

import 'models/prompt.dart';
import 'models/user.dart';

final GoogleSignIn googleSignIn = GoogleSignIn();

final usersRef = FirebaseFirestore.instance.collection('steve_users');
final chatRef = FirebaseFirestore.instance.collection('steve_convos');

late User currentUser;

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  // ignore: library_private_types_in_public_api
  CS createState() => CS();
}

class CS extends State<Home> {
  bool isAuth = false;
  bool isLoading = false;
  TextEditingController sub = TextEditingController();

  late OpenAI openAI;

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  List<Prompt> prompts = [];
  setGPT() async {
    openAI = OpenAI.instance.build(
        token: "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",
        baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 5)),
        enableLog: true);

    debugPrint("");
  }

  @override
  void initState() {
    super.initState();

    // Reauthenticate user when app is opened
    googleSignIn.signInSilently(suppressErrors: false).then((account) {
      if (account != null) {
        setState(() {
          isLoading = true;
        });
        handleSignIn(account);
      }
    }).catchError((err) {
      print('Error signing in: $err');
    });

    _initSpeech();
    setGPT();
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();

    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);

    setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      sub.text = _lastWords;
    });
  }

  login() {
    setState(() {
      isLoading = true;
    });

    googleSignIn.signIn();

    // Detects when user signed in
    googleSignIn.onCurrentUserChanged.listen((account) {
      if (account != null) {
        setState(() {
          isLoading = true;
        });
        handleSignIn(account);
      }
    }, onError: (err) {
      print('Error signing in: $err');
    });
  }

  logout() {
    setState(() {
      isLoading = false;
    });
    showDialog(
        context: context,
        builder: (context) {
          Future.delayed(const Duration(milliseconds: 500), () async {
            Navigator.of(context).pop(true);

            googleSignIn.signOut();

            setState(() {
              isAuth = false;

              isLoading = false;
            });
          });
          return AlertDialog(
            backgroundColor: Colors.white,
            title: const Text("Logging out!",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            content: Container(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: const LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.black),
              ),
            ),
          );
        });
  }

  handleSignIn(GoogleSignInAccount account) async {
    if (account.email.isNotEmpty) {
      print('User signed in!: $account');
      await createUserInFirestore();

      setState(() {
        isAuth = true;
        isLoading = false;
      });
    } else {
      setState(() {
        isAuth = false;
      });
    }
  }

  createUserInFirestore() async {
    // 1) check if user exists in users collection in database (according to their id)
    final GoogleSignInAccount? user = googleSignIn.currentUser;
    DocumentSnapshot doc = await usersRef.doc(user?.email).get();

    if (!doc.exists) {
      // 2) if the user doesn't exist, then we want to take them to the create account page
      // ignore: use_build_context_synchronously

      // 3) get username from create account, use it to make new user document in users collection
      usersRef.doc(user?.email).set({
        "email": user?.email,
        "displayName": user?.displayName,
        "timestamp": DateTime.now(),
      });

      doc = await usersRef.doc(user?.email).get();
    }

    currentUser = User.fromDocument(doc);
    print(currentUser.displayName);

    getprompts();

    setState(() {
      isLoading = false;
    });
  }

  getprompts() async {
    setState(() {
      isLoading = true;
      prompts = [];
    });

    QuerySnapshot snapshot = await chatRef
        .doc(currentUser.email)
        .collection("chats")
        .orderBy("timestamp", descending: false)
        .get();

    setState(() {
      prompts = snapshot.docs.map((doc) => Prompt.fromDocument(doc)).toList();
      prompts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isAuth == false) {
      return Scaffold(
          backgroundColor: _getColorFromHex("#21F3CE"),
          body: Column(
            children: [
              Container(height: 100),
              const Text("Steve Bot",
                  style: TextStyle(
                    fontFamily: "Bangers",
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 75.0,
                  ),
                  textAlign: TextAlign.center),
              Container(height: 40),
              Image.asset("images/bot.png", height: 256),
              Container(height: 40),
              SizedBox(
                  width: 250,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                    ),
                    onPressed: login,
                    child: Text("Sign in with Google",
                        style: TextStyle(
                          fontFamily: "Poppins-Bold",
                          fontWeight: FontWeight.bold,
                          color: _getColorFromHex("#21F3CE"),
                          fontSize: 16.0,
                        ),
                        textAlign: TextAlign.center),
                  )),
              Container(height: 20),
              if (isLoading) circularProgress()
            ],
          ));
    } else {
      return Scaffold(
        backgroundColor: _getColorFromHex("#21F3CE"),
        appBar: AppBar(
            centerTitle: true,
            title: const Text("Steve Bot",
                style: TextStyle(
                  fontFamily: "Poppins-Regular",
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 20.0,
                ),
                textAlign: TextAlign.center),
            actions: [
              IconButton(onPressed: logout, icon: const Icon(Icons.input))
            ]),
        body: RefreshIndicator(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              const Text("Copyright © 2023 Steve Bot. All rights reserved.",
                  style: TextStyle(
                    fontFamily: "Poppins-Regular",
                    //fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 12.0,
                  ),
                  textAlign: TextAlign.center),
              Container(height: 30),
              Image.asset("images/bot.png", height: 128),
              Container(height: 30),
              Text(
                  _speechEnabled
                      ? 'Tap the microphone to start speaking...'
                      : 'Speech not available',
                  style: const TextStyle(
                    fontFamily: "Poppins-Regular",
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 15.0,
                  ),
                  textAlign: TextAlign.center),
              Container(height: 10),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextFormField(
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  controller: sub,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Poppins-Regular"),
                  decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.all(Radius.circular(30.0)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.all(Radius.circular(30.0)),
                      ),
                      hintText: _speechToText.isNotListening
                          ? "Ask me anything.."
                          : "Say something..",
                      hintStyle: const TextStyle(
                          fontSize: 15.0, color: Color.fromRGBO(66, 66, 66, 1)),
                      suffixIcon: IconButton(
                          onPressed: () async {
                            setState(() {
                              isLoading = true;
                            });

                            if (sub.text.trim().isNotEmpty) {
                              final request = ChatCompleteText(messages: [
                                Messages(
                                    role: Role.assistant,
                                    content: "${sub.text.trim()}."),
                              ], maxToken: 100, model: GptTurboChatModel());

                              try {
                                ChatCTResponse? response = await openAI
                                    .onChatCompletion(request: request);
                                debugPrint("${response?.choices.length}");
                                debugPrint(
                                    "${response?.choices.last.message?.content}");
                                setState(() {
                                  String id = const Uuid().v4();

                                  chatRef
                                      .doc(currentUser.email)
                                      .collection("chats")
                                      .doc(id)
                                      .set({
                                    "email": currentUser.email,
                                    "question": sub.text.trim(),
                                    "response":
                                        response?.choices.last.message?.content,
                                    "id": id,
                                    "timestamp": DateTime.now(),
                                  });

                                  sub.clear();

                                  _lastWords = '';
                                });

                                getprompts();
                              } catch (e) {
                                // ignore: use_build_context_synchronously
                                showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                          backgroundColor:
                                              _getColorFromHex("#21F3CE"),
                                          title: const Text("Try Again",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontFamily: "Poppins-Bold",
                                                  fontSize: 16.0,
                                                  // fontWeight: FontWeight.bold,
                                                  color: Colors.black)),
                                          content: Text(
                                              "Your messages are reloading\n$e",
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 14.0,
                                                  fontFamily: "Poppins-Regular",
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black)),
                                        ));
                              }
                            } else {
                              showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                        backgroundColor:
                                            _getColorFromHex("#21F3CE"),
                                        title: const Text("Blank Entry",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontFamily: "Poppins-Bold",
                                                fontSize: 16.0,
                                                // fontWeight: FontWeight.bold,
                                                color: Colors.black)),
                                        content: const Text(
                                            "You haven't entered anything.\nIf you used the voice assistant. Please try again, we weren't able to identify your voice.",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 14.0,
                                                fontFamily: "Poppins-Regular",
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black)),
                                      ));
                            }

                            setState(() {
                              isLoading = false;
                            });
                          },
                          icon: const Icon(
                            Icons.send,
                            color: Colors.black,
                          )),
                      prefixIcon: IconButton(
                          onPressed: _speechToText.isNotListening
                              ? _startListening
                              : _stopListening,
                          icon: Icon(
                            _speechToText.isNotListening
                                ? Icons.mic_off
                                : Icons.mic,
                            color: Colors.black,
                          ))),
                ),
              ),
              if (isLoading == true) circularProgress(),
              if (prompts.isEmpty && isLoading == false)
                ChatBubble(
                    elevation: 10,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.topLeft,
                    clipper:
                        ChatBubbleClipper3(type: BubbleType.receiverBubble),
                    backGroundColor: Colors.red[800],
                    child: InkWell(
                      onLongPress: () {},
                      child: Container(
                          padding: const EdgeInsets.only(
                              left: 8, right: 8, top: 4, bottom: 4),
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width * 0.6,
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          child: Column(children: [
                            Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                      child: RichText(
                                    text: TextSpan(
                                      text: ("ChatGPT : "),
                                      style: const TextStyle(
                                        fontFamily: "Poppins-Bold",
                                        //fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        fontSize: 16.0,
                                      ),
                                      children: <TextSpan>[
                                        TextSpan(
                                            text:
                                                "Hi ${currentUser.displayName.split(" ")[0]}, how can I help you?",
                                            style: const TextStyle(
                                              fontFamily: "Poppins-Regular",
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                              fontSize: 16.0,
                                            )),
                                      ],
                                    ),
                                  )),
                                  Container(width: 0)
                                ]),
                            Container(height: 5),
                          ])),
                    )),
              if (prompts.isNotEmpty && isLoading == false)
                for (int i = 0; i < prompts.length; i++)
                  Column(children: [
                    if (i == 0 ||
                        (funny1(prompts[i].timestamp.toDate().toString()) !=
                            funny1(
                                prompts[i - 1].timestamp.toDate().toString())))
                      Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              disabledBackgroundColor: Colors.grey[900],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30.0)),
                            ),
                            onPressed: null,
                            child: Text(
                              funny1(prompts[i].timestamp.toDate().toString()),
                              style: const TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          )),
                    ChatBubble(
                        elevation: 10,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.topRight,
                        clipper:
                            ChatBubbleClipper3(type: BubbleType.sendBubble),
                        backGroundColor: Colors.amber[300],
                        child: InkWell(
                          onLongPress: () {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return SimpleDialog(
                                    backgroundColor: Colors.white,
                                    title: const Text(
                                      "OPTIONS",
                                      //  textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.black,
                                          fontFamily: "Poppins-Bold"),
                                    ),
                                    children: <Widget>[
                                      SimpleDialogOption(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text(
                                            'Delete Message',
                                            //     textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.red[900],
                                                fontWeight: FontWeight.bold,
                                                fontFamily: "Poppins-Regular"),
                                          )),
                                      SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text(
                                            'CANCEL',
                                            // textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: "Poppins-Regular"),
                                          )),
                                    ],
                                  );
                                });
                          },
                          child: Container(
                              padding: const EdgeInsets.only(
                                  left: 8, right: 8, top: 4, bottom: 4),
                              constraints: BoxConstraints(
                                minHeight: double.minPositive,
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.6,
                              ),
                              child: Column(children: [
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Flexible(
                                          child: RichText(
                                        text: TextSpan(
                                          text: ("You : "),
                                          style: const TextStyle(
                                            fontFamily: "Poppins-Bold",
                                            //fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                            fontSize: 16.0,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                                text: prompts[i].question,
                                                style: const TextStyle(
                                                  fontFamily: "Poppins-Regular",
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 16.0,
                                                )),
                                          ],
                                        ),
                                      )),
                                      Container(width: 0)
                                    ]),
                                Container(height: 5),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        funny(prompts[i]
                                            .timestamp
                                            .toDate()
                                            .toString()),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54),
                                      ),
                                      const SizedBox(
                                        height: 0,
                                        width: 0,
                                      )
                                    ])
                              ])),
                        )),
                    ChatBubble(
                        elevation: 10,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.topLeft,
                        clipper:
                            ChatBubbleClipper3(type: BubbleType.receiverBubble),
                        backGroundColor: Colors.red[800],
                        child: InkWell(
                          onLongPress: () {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return SimpleDialog(
                                    backgroundColor: Colors.white,
                                    title: const Text(
                                      "OPTIONS",
                                      //  textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.black,
                                          fontFamily: "Poppins-Bold"),
                                    ),
                                    children: <Widget>[
                                      SimpleDialogOption(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text(
                                            'Delete Message',
                                            //     textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.red[900],
                                                fontWeight: FontWeight.bold,
                                                fontFamily: "Poppins-Regular"),
                                          )),
                                      SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text(
                                            'CANCEL',
                                            // textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: "Poppins-Regular"),
                                          )),
                                    ],
                                  );
                                });
                          },
                          child: Container(
                              padding: const EdgeInsets.only(
                                  left: 8, right: 8, top: 4, bottom: 4),
                              constraints: BoxConstraints(
                                minHeight: double.minPositive,
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.6,
                              ),
                              child: Column(children: [
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Flexible(
                                          child: RichText(
                                        text: TextSpan(
                                          text: ("ChatGPT : "),
                                          style: const TextStyle(
                                            fontFamily: "Poppins-Bold",
                                            //fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                            fontSize: 16.0,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                                text: prompts[i].response,
                                                style: const TextStyle(
                                                  fontFamily: "Poppins-Regular",
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 16.0,
                                                )),
                                          ],
                                        ),
                                      )),
                                      Container(width: 0)
                                    ]),
                                Container(height: 5),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        funny(prompts[i]
                                            .timestamp
                                            .toDate()
                                            .toString()),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54),
                                      ),
                                      const SizedBox(
                                        height: 0,
                                        width: 0,
                                      )
                                    ])
                              ])),
                        )),
                    //
                    //
                    //
                    //
                  ])
            ],
          ),
          onRefresh: () {
            setState(() {
              isLoading = false;
              sub.clear();

              _lastWords = '';

              getprompts();
            });
            return Future(() => false);
          },
        ),

        /* floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber[300],
        onPressed:
            // If not yet listening for speech start, otherwise stop
            _speechToText.isNotListening ? _startListening : _stopListening,
        tooltip: 'Listen',
        child: Icon(
          _speechToText.isNotListening ? Icons.mic_off : Icons.mic,
          size: 30,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,*/
      );
    }
  }
}

_getColorFromHex(String hexColor) {
  hexColor = hexColor.replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF$hexColor";

    return Color(int.parse("0x$hexColor"));
  }

  if (hexColor.length == 8) {
    return Color(int.parse("0x$hexColor"));
  }
}

String funny(String x) {
  String a;
  print(x);
  a = x.substring(11, 16);
  print(a);
  int p = int.parse(a.substring(0, 2));
  print(p);
  if (p == 0) {
    p += 12;
    print(p);
    a = "$p${x.substring(13, 16)} AM";
  } else if (p >= 1 && p <= 11) {
    a = "$a AM";
  } else if (p == 12) {
    a = "$a PM";
  } else if (p > 12) {
    p -= 12;
    print(p);
    a = "$p${x.substring(13, 16)} PM";
  }

  print(a);
  return a;
}

String funny1(String x) {
  late String a, b, c;
  int q;

  a = x.substring(11, 16);
  int p = int.parse(a.substring(0, 2));
  if (p == 0) {
    p += 12;
    a = "${String.fromCharCode(p)}${x.substring(13, 16)} AM";
  } else if (p >= 1 && p <= 11) {
    a = "$a AM";
  } else if (p == 12) {
    a = "$a PM";
  } else if (p > 12) {
    p -= 12;
    a = "${String.fromCharCode(p)}${x.substring(13, 16)} PM";
  }

  b = x.substring(2, 4);
  q = int.parse(x.substring(5, 7));

  switch (q) {
    case 1:
      c = "Jan";
      break;
    case 2:
      c = "Feb";
      break;
    case 3:
      c = "Mar";
      break;
    case 4:
      c = "Apr";
      break;
    case 5:
      c = "May";
      break;
    case 6:
      c = "Jun";
      break;
    case 7:
      c = "Jul";
      break;
    case 8:
      c = "Aug";
      break;
    case 9:
      c = "Sep";
      break;
    case 10:
      c = "Oct";
      break;
    case 11:
      c = "Nov";
      break;
    case 12:
      c = "Dec";
      break;
    default:
      break;
  }

  b = "${x.substring(8, 10)}-$c-$b";

  return b;
}

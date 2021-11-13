import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart'; // Add this line.
import 'package:firebase_core/firebase_core.dart';
import 'package:hello_me/cloud_repo.dart';
import 'package:hello_me/store_repo.dart';
import 'package:provider/provider.dart';
import 'package:hello_me/auth_repo.dart';
import 'package:snapping_sheet/snapping_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final scaf = Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
          return MaterialApp(home: scaf);
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return MyApp();
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => AuthRepository.instance(),
        child: MaterialApp(
          title: 'Startup Name Generator',
          theme: ThemeData(
            primarySwatch: Colors.deepPurple,
          ),
          home: const RandomWords(),
        ));
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  var _saved = <WordPair>{};
  final _biggerFont = const TextStyle(fontSize: 18);
  final StoreRepository firestore = StoreRepository();
  final CloudRepository cloud = CloudRepository();
  MyUser? myUser;
  String? profileUrl;
  bool _firstLoad = true;
  SnappingSheetController snapController = SnappingSheetController();
  double blurFactor = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthRepository>(builder: (context, auth, _) {
      return Scaffold(
          appBar: AppBar(title: const Text('Startup Name Generator'), actions: [
            IconButton(
                icon: const Icon(Icons.star),
                onPressed: _pushSaved,
                tooltip: 'Saved Suggestions'),
            IconButton(
                icon: Icon(auth.status == Status.LoggedIn
                    ? Icons.exit_to_app
                    : Icons.login),
                onPressed: auth.status == Status.LoggedIn
                    ? (() => _signOut(auth))
                    : _pushLogin)
          ]),
          body: _buildMainScreen(auth));
    });
  }

  Widget _buildMainScreen(AuthRepository auth) {
    if (auth.user != null) {
      if (_firstLoad) {
        _loadUserSaved(auth);
        _firstLoad = false;
      }

      return SnappingSheet(
        controller: snapController,
        child: Stack(
          children: [
            _buildSuggestions(auth),
            BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: 20 * blurFactor, sigmaY: 20 * blurFactor),
              child: Container(),
            ),
          ],
        ),
        lockOverflowDrag: true,
        snappingPositions: const [
          SnappingPosition.factor(
            positionFactor: 0.0,
            snappingCurve: Curves.easeOutExpo,
            snappingDuration: Duration(seconds: 1),
            grabbingContentOffset: GrabbingContentOffset.top,
          ),
          SnappingPosition.factor(
            snappingCurve: Curves.elasticOut,
            snappingDuration: Duration(milliseconds: 1750),
            positionFactor: 0.2,
          ),
          SnappingPosition.factor(
            grabbingContentOffset: GrabbingContentOffset.bottom,
            snappingCurve: Curves.elasticOut,
            snappingDuration: Duration(seconds: 1),
            positionFactor: 0.7,
          ),
        ],
        grabbing: GestureDetector(
          onTap: () {
            setState(() {
              if (snapController.currentSnappingPosition ==
                  const SnappingPosition.factor(positionFactor: 0)) {
                snapController.snapToPosition(
                    const SnappingPosition.factor(positionFactor: 0.2));
              } else {
                snapController.snapToPosition(const SnappingPosition.factor(
                  positionFactor: 0.0,
                  snappingCurve: Curves.easeOutExpo,
                  snappingDuration: Duration(seconds: 1),
                  grabbingContentOffset: GrabbingContentOffset.top,
                ));
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(199, 199, 199, 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Welcome back, ${auth.user!.email}"),
                const Icon(Icons.keyboard_arrow_up_rounded)
              ],
            ),
          ),
        ),
        grabbingHeight: 50,
        sheetAbove: null,
        sheetBelow: SnappingSheetContent(
          draggable: true,
          child: _buildProfileSection(auth),
        ),
        onSheetMoved: (snappingPosition) {
          setState(() {
            double bodyHeight = MediaQuery.of(context).size.height;
            blurFactor = snapController.currentPosition / bodyHeight;
            if (blurFactor < 0.1) {
              blurFactor = 0;
            } // avoid blurring in basic case
          });
        },
      );
    } else {
      return _buildSuggestions(auth);
    }
  }

  Widget _buildProfileSection(AuthRepository auth) {
    return Container(
      color: const Color.fromRGBO(245, 245, 245, 1),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        title: Text(
          '${auth.user!.email}',
          style: const TextStyle(fontSize: 20),
        ),
        leading: CircleAvatar(
            backgroundColor: Colors.grey,
            backgroundImage:
                (profileUrl == null) ? null : NetworkImage(profileUrl!),
            radius: 30),
        subtitle: ElevatedButton(
          style: ElevatedButton.styleFrom(
              primary: const Color.fromRGBO(0, 138, 166, 1)),
          onPressed: () async {
            FilePickerResult? result =
                await FilePicker.platform.pickFiles(type: FileType.image);

            if (result != null) {
              File file = File(result.files.single.path!);
              String url = await cloud.uploadNewImage(file, auth.user!.email!);
              setState(() {
                profileUrl = url;
              });
            } else {
              _showSnackbar("No image selected");
            }
          },
          child: const Text('Change avatar'),
        ),
      ),
    );
  }

  Widget _buildSuggestions(AuthRepository auth) {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemBuilder: (BuildContext _context, int i) {
          if (i.isOdd) {
            return const Divider();
          }

          final int index = i ~/ 2;
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(
              _suggestions[index]); // also takes care of loaded favorites
        });
  }

  void _loadUserSaved(AuthRepository auth) async {
    if (auth.user != null) {
      String mail = auth.user!.email ?? ""; // won't be null
      var tmpList = await firestore.getUserList(mail);
      var profileImage = "";
      try {
        profileImage = await cloud.getImageUrl(mail);
      } catch (e) {
        profileImage = await cloud.getDefaultImageUrl();
      }

      setState(() {
        profileUrl = profileImage;
        _saved = tmpList!.toSet();
        myUser = MyUser(mail, _saved.toList());
        log("loaded connected user: ${myUser!.email} with favorites: ${_saved.toString()}");
      });
    }
  }

  Widget _buildRow(WordPair pair) {
    final alreadySaved = _saved.contains(pair);
    return ListTile(
      title: Text(
        pair.asPascalCase,
        style: _biggerFont,
      ),
      trailing: Icon(
        alreadySaved ? Icons.star : Icons.star_border,
        color: alreadySaved ? Colors.deepPurple : null,
        semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
      ),
      onTap: () {
        setState(() {
          if (alreadySaved) {
            _saved.remove(pair);
            if (myUser != null) {
              myUser!.favorites = _saved.toList();
              firestore.updateUser(myUser!);
            }
          } else {
            _saved.add(pair);
            if (myUser != null) {
              myUser!.favorites = _saved.toList();
              firestore.updateUser(myUser!);
            }
          }
        });
      },
    );
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final tiles = _saved.map(
            (pair) {
              return Dismissible(
                  child: ListTile(
                    title: Text(
                      pair.asPascalCase,
                      style: _biggerFont,
                    ),
                  ),
                  key: UniqueKey(),
                  background: Container(
                      color: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        children: const [
                          Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                          Text('Delete Suggestion',
                              style: TextStyle(color: Colors.white))
                        ],
                      )),
                  confirmDismiss: (direction) => _showDismissDialog(pair));
            },
          );

          final divided = tiles.isNotEmpty
              ? ListTile.divideTiles(
                  context: context,
                  tiles: tiles,
                ).toList()
              : <Widget>[];

          return Scaffold(
            appBar: AppBar(
              title: const Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }

  void _pushLogin() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return Scaffold(
              appBar: AppBar(
                title: const Text('Login'),
              ),
              body: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                alignment: AlignmentDirectional.centerStart,
                child: Column(
                  children: <Widget>[
                    const Text(
                        "Welcome to Startup Names Generator, please log in below"),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Consumer<AuthRepository>(
                        builder: (context, auth, _) => TextButton(
                              style: TextButton.styleFrom(
                                  primary: Colors.white,
                                  backgroundColor: Colors.deepPurple,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 80),
                                  shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(15))),
                                  minimumSize: const Size(double.infinity, 40)),
                              onPressed: (auth.status == Status.Logging)
                                  ? null
                                  : (() => _signIn(auth, emailController,
                                      passwordController)),
                              child: const Text("Log in"),
                            )),
                    const SizedBox(height: 10),
                    Consumer<AuthRepository>(
                        builder: (context, auth, _) => TextButton(
                              style: TextButton.styleFrom(
                                  primary: Colors.white,
                                  backgroundColor: Colors.lightBlue,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(15))),
                                  minimumSize: const Size(double.infinity, 40)),
                              onPressed: (auth.status == Status.Logging)
                                  ? null
                                  : (() => _signUp(auth, emailController,
                                      passwordController)),
                              child: const Text("New user? Click to sign up"),
                            )),
                  ],
                ),
              ));
        },
      ),
    );
  }

  void _signUp(AuthRepository auth, TextEditingController emailController,
      TextEditingController passwordController) async {
    final TextEditingController confirmedPasswordController =
        TextEditingController();

    showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(
                      child: Text(
                    "Please confirm your password below:",
                    style: TextStyle(fontSize: 15),
                  )),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmedPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                      child: TextButton(
                    style: TextButton.styleFrom(
                        primary: Colors.white,
                        backgroundColor: Colors.lightBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 80),
                        shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(5)))),
                    onPressed: (auth.status == Status.Logging)
                        ? null
                        : (() async {
                            if (passwordController.text !=
                                confirmedPasswordController.text) {
                              _showSnackbar("Passwords must match");
                              Navigator.pop(context);
                            } else {
                              await auth.signUp(emailController.text,
                                  passwordController.text);
                              var profile =
                                  await cloud.getDefaultImageUrl(); // new user
                              Navigator.pop(context);
                              setState(() {
                                profileUrl = profile;
                                myUser = MyUser(
                                    emailController.text, _saved.toList());
                                firestore.updateUser(myUser!);
                              });
                              Navigator.pop(context);
                            }
                          }),
                    child: const Text("Confirm"),
                  )),
                  Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom))
                ],
              )));
        });
  }

  void _signIn(AuthRepository auth, TextEditingController emailController,
      TextEditingController passwordController) async {
    bool connected =
        await auth.signIn(emailController.text, passwordController.text);
    if (connected) {
      List<WordPair>? userList =
          await firestore.getUserList(emailController.text);
      Set<WordPair>? newSet = _mergeSets(userList!.toSet(), _saved);
      var profileImage = "";
      try {
        profileImage = await cloud.getImageUrl(emailController.text);
      } catch (e) {
        profileImage = await cloud.getDefaultImageUrl();
      }

      setState(() {
        profileUrl = profileImage;
        _saved = newSet!;
        myUser = MyUser(emailController.text, _saved.toList());
        firestore.updateUser(myUser!);
      });

      Navigator.pop(context);
    } else {
      // login error, reason doesn't matter
      _showSnackbar('There was an error logging into the app');
    }
  }

  void _signOut(AuthRepository auth) async {
    await auth.signOut();
    setState(() {
      profileUrl = null;
      myUser = null;
      _saved = {};
    });
    _showSnackbar('Successfully logged out');
  }

  void _showSnackbar(String msg) {
    final snackBar = SnackBar(content: Text(msg));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<bool?> _showDismissDialog(WordPair pair) async {
    return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text("Delete Suggestion"),
                    content: Text(
                        "Are you sure you want to delete ${pair.asPascalCase} from your saved suggestions?"),
                    actions: <Widget>[
                      TextButton(
                          onPressed: () {
                            setState(() {
                              _saved.remove(pair);
                              if (myUser != null) {
                                myUser!.favorites = _saved.toList();
                                firestore.updateUser(myUser!);
                              }
                            });
                            Navigator.of(context).pop(true);
                          },
                          child: const Text('Yes')),
                      TextButton(
                          onPressed: () {
                            return Navigator.of(context).pop(false);
                          },
                          child: const Text('No'))
                    ])) ??
        false;
  }

  Set<WordPair>? _mergeSets(Set<WordPair> a, Set<WordPair> b) {
    List<WordPair> aList = a.toList();
    List<WordPair> bList = b.toList();
    return [...aList, ...bList].toSet();
  }
}

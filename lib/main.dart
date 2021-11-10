//import 'dart:ui';

import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart'; // Add this line.
import 'package:firebase_core/firebase_core.dart';
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
  final StoreRepository repository = StoreRepository();
  MyUser? myUser;
  bool _firstLoad = true;
  SnappingSheetController snapController = SnappingSheetController();

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
          body: _buildSnappingSheet(auth));
    });
  }

  Widget _buildSnappingSheet(AuthRepository auth) {
    if (auth.user != null) {
      return SnappingSheet(
        controller: snapController,
        child: _buildSuggestions(auth),
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
        grabbing: Container(
          decoration: const BoxDecoration(
            color: Color.fromRGBO(199, 199, 199, 1),
          ),
          child: Center(
            child: Text("Welcome back, ${auth.user!.email}"),
          ),
        ),
        grabbingHeight: 50,
        sheetAbove: null,
        sheetBelow: SnappingSheetContent(
          draggable: true,
          child: _buildProfileSection(auth),
        ),
      );

      /*double body_height = MediaQuery.of(context).size.height;
      //double k = snapController.currentPosition / body_height;

      return Stack(
        children: [
          _buildSuggestions(auth),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0), // TODO: Add blur
            child: Container(color: Colors.transparent),
            snap
          ),
        ],
      );*/
    } else {
      return _buildSuggestions(auth);
    }
  }

  Widget _buildProfileSection(AuthRepository auth) {
    return Container(
      color: const Color.fromRGBO(245, 245, 245, 1),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        title: Text('${auth.user!.email}'),
        leading: CircleAvatar(radius: 30),
        subtitle: ElevatedButton(
          style: ElevatedButton.styleFrom(
              primary: const Color.fromRGBO(0, 138, 166, 1)),
          onPressed: () {}, // TODO
          child: const Text('Change avatar'),
        ),
      ),
    );
  }

  Widget _buildSuggestions(AuthRepository auth) {
    if (_firstLoad) {
      _loadUserSaved(auth);
      _firstLoad = false;
    }

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
      var tmp_list = await repository.getUserList(mail);

      setState(() {
        _saved = tmp_list!.toSet();
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
              repository.updateUser(myUser!);
            }
          } else {
            _saved.add(pair);
            if (myUser != null) {
              myUser!.favorites = _saved.toList();
              repository.updateUser(myUser!);
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
                                          Radius.circular(5)))),
                              onPressed: (auth.status == Status.Logging)
                                  ? null
                                  : (() => _signIn(auth, emailController,
                                      passwordController)),
                              child: const Text("Login"),
                            )),
                  ],
                ),
              ));
        },
      ),
    );
  }

  void _signIn(AuthRepository auth, TextEditingController emailController,
      TextEditingController passwordController) async {
    bool connected =
        await auth.signIn(emailController.text, passwordController.text);
    if (connected) {
      List<WordPair>? user_list =
          await repository.getUserList(emailController.text);
      Set<WordPair>? new_set = _mergeSets(user_list!.toSet(), _saved);

      setState(() {
        _saved = new_set!;
        myUser = MyUser(emailController.text, _saved.toList());
        repository.updateUser(myUser!);
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
                                repository.updateUser(myUser!);
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

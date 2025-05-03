import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Container(
          width: double.infinity, // Force la largeur maximale
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blueAccent, Colors.lightBlueAccent],
            ),
          ),
          child: SafeArea(
            // Ajoute une marge de sécurité pour les notches et barres système
            child: Column(
              mainAxisSize: MainAxisSize.max, // Force la hauteur maximale
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment
                  .stretch, // Force la largeur maximale pour les enfants
              children: [
                // Ajout du logo fictif
                Center(
                  // Centre l'icône horizontalement
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.brush_rounded,
                      size: 100.0,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Nom de l'application
                Center(
                  // Centre le texte horizontalement
                  child: Text(
                    'Pictionis',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 20),

                // Bouton pour démarrer le jeu
                Center(
                  // Centre le bouton horizontalement
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      shadowColor: Colors.black,
                      elevation: 5,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: Text(
                      'JOUER',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 40),

                Center(
                  // Centre le texte horizontalement
                  child: Text(
                    'Dessine et devine avec tes amis !',
                    style: TextStyle(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

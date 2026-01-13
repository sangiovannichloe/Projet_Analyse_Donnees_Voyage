README
================

# Outil de recommandation de destinations de voyage personnalisées

**Analyse de données - M1 APE - 2025-2026**

**Rebecca BALLANCIN - Chloé SANGIOVANNI - Heidi MILLION**

------------------------------------------------------------------------

## Présentation du projet

Notre projet vise à répondre à une question que beaucoup de voyageurs se
posent :  
**quelle destination de voyage correspond le mieux à mon profil, à mes
préférences et à mes contraintes ?**

Afin de pouvoir utiliser notre programme, il est nécessaire de
télécharger le script R fourni ainsi que la base de données associée.  
La base de données doit être placée dans l’environnement de travail
RStudio.  
Il convient également de vérifier que les packages requis (`tidyverse`,
`jsonlite`) sont bien installés.

Pour répondre à la question posée, nous avons développé un programme en
R qui **interagit avec l’utilisateur** en lui posant une série de
questions portant sur ses préférences de voyage et ses contraintes.  
À partir de ces réponses, le programme compare différentes villes
présentes dans la base de données et propose un **Top 5 de
destinations** les plus adaptées au profil de l’utilisateur.

------------------------------------------------------------------------

## Critères pris en compte

Les critères utilisés dans le programme sont les suivants :

- **Culture** : intérêt pour les musées, le patrimoine et l’histoire  
- **Aventure** : attrait pour les activités dynamiques et les
  expériences nouvelles  
- **Nature** : importance accordée aux paysages naturels et aux
  activités de plein air  
- **Plage** : préférence pour les destinations balnéaires  
- **Vie nocturne** : intérêt pour les sorties et animations nocturnes  
- **Cuisine / gastronomie** : importance de la découverte culinaire  
- **Bien-être** : recherche de détente et de relaxation  
- **Ambiance urbaine** : préférence pour les grandes villes  
- **Isolement / calme** : volonté d’éviter la foule

Pour chacun de ces critères, l’utilisateur attribue une note comprise
entre **0 et 5**, ce qui permet de définir son **profil de voyageur**.

En complément, l’utilisateur doit également préciser : - son **niveau de
budget** (Budget, Mid-range ou Luxury)  
- la **durée du séjour** souhaitée  
- une **ville de départ**  
- un **budget total maximal**  
- un **mode de transport**  
- et, de manière optionnelle, des **contraintes météorologiques** (mois
et plage de températures)

------------------------------------------------------------------------

## Construction du programme

Lors de la création de ce projet, nous avons dans un premier temps
travaillé sur la **mise en forme et la lisibilité de la base de
données**, notamment en traitant des variables stockées au format JSON
(durées de séjour recommandées et températures mensuelles).

Nous avons ensuite créé plusieurs **fonctions dédiées** permettant : -
de poser des questions à l’utilisateur avec des réponses encadrées, - de
limiter les erreurs de saisie, - de standardiser les entrées
utilisateur.

Ces fonctions sont ensuite appelées au sein d’une **fonction
principale**, qui regroupe l’ensemble de la logique du programme.

------------------------------------------------------------------------

## Fonctionnement de la fonction principale

Dans un premier temps, les préférences utilisateur sont collectées et
**normalisées**, afin que leur somme soit égale à 1.  
Cette étape permet de comparer correctement les villes entre elles en
tenant compte uniquement des priorités relatives de l’utilisateur.

Dans un second temps, les villes sont filtrées selon les **contraintes
de budget et de durée** afin d’exclure les destinations irréalistes.

Nous avons ensuite enrichi le programme en intégrant une estimation du
**coût total du voyage**.  
Pour cela : - la distance entre la ville de départ et chaque destination
est calculée à l’aide de la formule de **Haversine** ; - un coût de
transport est estimé selon le mode de transport choisi ; - un coût
journalier est associé au niveau de budget de la ville ; - le coût total
correspond à la somme du transport et du séjour.

Les villes dépassant le budget total maximal de l’utilisateur sont alors
supprimées.

Dans un troisième temps, l’utilisateur peut activer un **filtre
météo**.  
Le programme conserve uniquement les villes dont la température moyenne
du mois choisi correspond à la plage de températures souhaitée.

------------------------------------------------------------------------

## Calcul du score et résultats

À partir des villes restantes, un **score utilisateur** est calculé pour
chacune d’entre elles.  
Ce score correspond à une **somme pondérée des scores thématiques** de
la ville, où les poids sont déterminés par les préférences de
l’utilisateur.

Les villes sont ensuite classées par score décroissant et le programme
retourne : - un **Top 5 de destinations**, - le score utilisateur
associé, - le coût total estimé du voyage, - ainsi que la température
moyenne (si le filtre météo est activé).


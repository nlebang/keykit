
function Go()			# (appel�e au d�marrage dans le postrc)
{
	print("-G�oMaestro-v0.7")

#	FrenchBlahBlah()
	EnglishBlahBlah()

#	Modir = 1		# console en mode direct 

	InitStatique()			

	Bavard = 0		# Sc�ne de base (en mode silencieux)	

	if (fileexists(BASE+"init.ev"))
	   LoadEv("init", BASE)
	else
	   ExLScene()			# Ev en provenance d'Excel

	if (fileexists(BASE+"init.geo"))
	   Geo("init", BASE)
		
	RestoreChantier()
	
	Bavard = 1		# mode Bavard (les Bprint fonctionnent)
       #DebProf = 1		# mode d�buggage (DEBUG � toutes profondeurs)
        DebProf = 5		#		  DEBUG(5,...) et plus seulement 

	Recsched = 1
}

			

#########################################################################################
########								#################
########  Initialisations						#################
########								#################
#########################################################################################



function InitStatique()		# proc�de � toutes les initialisations
{
	InitConstantes()

	InitVolume()
	InitPan()
	InitPit()
	InitPB()
	InitDur()

	InitParameters()	# ... dans lib_dist.k

	InitACPat()		# ...dans audiocompositor.k
}
										
			
function InitConstantes()	# Constantes, variables r�serv�es et options
{
	Pi = 3.141592653589793218474		# ...vraiment ?

	# volume minimal pour que persiste une note:
	SILENCE = 10

	# Modes bavard et d�bug:
	Bavard = 1	
	DebProf = 5	# DEBUG(n,...) s'affiche si n >= DebProf	

	# Notepad():
	#		le fichier "nom" sera ouvert par NOTEPAD1+"nom"+NOTEPAD2
	NOTEPAD1 = "Notepad.exe "	
	NOTEPAD2 = ""

	# r�pertoires utiles:
	MDOP=	"../MIDI/"
	MAT=    "../contrib/GeoMaestro/"
	DATA=	MAT+"data/"
	COMPOS=	MAT+"userlib/"
	VRAC =	MDOP+"Vrac/"

	TEMPFILE = DATA+"temp.txt"		# nom de fichier par d�faut pour Notepad()
	BASE=	COMPOS+"Courant/"	# compositions courantes

	# R�pertoire d'�criture par d�faut 
	#  (utilis� par RacineN() et FichierN())
	DEFDIR = DATA


	# console:
	GEOCOMMENT = "D�fini � la console:"	# pour Sgeo()
	FT = []					# fonctions de T (history)
	FKK = []				# fonctions de X, Y, N, C (history)
	FIF = []				# tests sur X, Y, N, C (history)
	LOG = []				
	SNARF = []
	GVARS = []				# variables globales � retenir		

	# lignes cr��es par l'outil graphique:
	RL = []		

	# Nombre de clicks par centim�tre, par d�faut
	CPCM = seconds(1)     # ici, une seconde (192 clicks) par centim�tre


	# nombre de canaux g�r�s:
	NbCan = 20	   # 16 midi (� instrument unique)
			   # + 4 fourre-tout G�oMaestro (qui utilisent les
			   #   n derniers canaux midis pour des compositions � n notes)


	# pour op�rations sur les r�gions:

	Tout = [0=0]	 # r�gion vide (pas de calcul de r�gion effectu�)

	EnPlusDe = ""	 # op pour ajouter (OU) la r�gion
	EnMoinsDe = "!"	 # op pour ajouter (OU) le n�gatif de la r�gion


	# variables globales r�serv�es pour des calculs temporaires (par eval):
	# X_, Y_, C_, Ev, Ln, A_, P_, L_
	# G__, K__
	# N_, T__, S_		
	# G__G, N_N

	# pour utilisation par Excel et par eval():
	Xs = "x"
	Ys = "y"
	Cs = "c"
	Rs = "r"
	Ph = "nodur"
	As = "actif"
	Ss = "s"
	PACs = "PAC"
	Ds = "desc"
	INTERs = "inter"
	RACs = "rac"
	CERs = "cer"
	PAs = "A"
	PBs = "B"

	InitLiveAC()
}							

function InitLiveAC() {
	if (! defined(LiveAC)) {
		# garde le PourAC du canal ch, choisi par wprogch
		LiveAC = [1='', 2='', 3='', 4='', 5='', 6='', 7='', 8='',
			9='', 10='', 11='', 12='', 13='', 14='', 15='', 16='']
	}
}

function InitVolume()	# fonction de volume par d�faut, pour chaque canal
{
	Volume = []
	for (c=1; c<= NbCan; c++) Volume[c] = "MemeVol"		# d�faut	
}


function InitPan()	# fonction de st�r�o par d�faut, pour chaque canal
{
	Pan = []
	for (c=1; c<= NbCan; c++) Pan[c] = "BasicPan"		# d�faut

	Pan[3] = "LargePan"
	Pan[4] = "LargePan"
	Pan[14] = "LargePan"
	Pan[15] = "LargePan"
	Pan[16] = "LargePan"
}


function InitPit()	# fonction de pitch par d�faut, pour chaque canal
{
	Pit = []
	for (c=1; c<= NbCan; c++) Pit[c] = "BasicPitch"		# d�faut

	Pit[3] = "DopplerLateral"
	Pit[4] = "DopplerLateral"
	Pit[14] = "DopplerLateral"
	Pit[15] = "DopplerLateral"	
	Pit[16] = "DopplerLateral"
}


function InitPB()	# fonction de pitch bend par d�faut, pour chaque canal
{
	PB = []
	for (c=1; c<= NbCan; c++) PB[c] = "NoBend"		# d�faut
}


function InitDur()	# fonction de dur�e par d�faut, pour chaque canal
{
	Dur = []
	for (c=1; c<= NbCan; c++) Dur[c] = "MemeDur"		# d�faut
}



function InitEv()		# Appel�e par ExL.k	
{							
	Ev = [0=0]			
	for (nc = 1; nc <= NbCan; nc++) {Ev[nc]=[0=0, "PAC"= '']}					

	AcVar=[]
}




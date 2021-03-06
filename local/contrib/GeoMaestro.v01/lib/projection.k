###########################################################################################
#
#  G�oMaestro  v0.8							(Juillet 2000)
#
###########################################################################################



###########################################################################################
########			###########################################################
######## Structures de donn�es  ###########################################################
########			###########################################################
###########################################################################################


# Format des donn�es g�n�r�es par les projecteurs g�om�triques (les "lignes") :
# -----------------------------------------------------------------------------
# ligne["ph"]	 phrase musicale en elle-m�me
# ligne[0]	 temps de d�but (pas forc�ment la premi�re note de la phrase !)
# ligne[1]	 temps de fin (pas forc�ment la derni�re !)
# ligne["para"]  garde trace de certains param�tres de l'invocation du g�n�rateur
# ligne["id"]	 identification du g�n�rateur
# ligne["rac"]	 est un tableau sp�cifique au g�n�rateur, utile pour passer les param�tres 
#		 permettant des raccords propres entre les diff�rents algorithmes/mouvements,
#		 comme la position finale d'un segment modifi� par le g�n�rateur Brown() 
# ligne["inter"] permet de reconstruire/se raccorder � des positions interm�diaires du calcul 
#		 (ex. dans Brown() ou dans Echelle() )
#
#		 en particulier:
#		 ["inter"][0]		nbe d'�tats interm�diaires
#		 ["inter"][n]["A"]	typique des g�n. bas�s sur ProjSeg
#			     ["B"]       (interm�diaires = segments)		
#		 ["inter"][n]["c"]	typique des g�n. bas�s sur ProjCer 
#		             ["s"]	 (interm. = cercle orient�, d'o� sens)



# Points/vecteurs:
#-----------------
# v["x", "y"]		coord. rectangulaires (ex: return de Setpolar), STANDARD
#	 ou bien
# v["r", "theta"]	coord. polaires (principalement: return de Getpolar)
#			 (� ne pas utiliser dans un appel de fonction !)


# Cercles:
#---------
# cerc["c", "r"]	o� cerc["c"] est un point en rectangulaire (d'o� cerc["c"]["x"]...)


# R�gions:
#---------		
# blob[0]	nombre de ET-tests d�limitant la r�gion, li�s entre eux par des OU
# blob[n]	ET-test num�ro n, sur les variables X, Y et C (voir catalogue.k)		


# Ev�nements:
#------------
# (variable globale r�serv�e Ev)
#
# Ev[ch][0]		nbe total d'�v�nements dans le canal ch
# Ev[ch]["PAC"]	phrase d'initialisation du canal
# Ev[ch][n]["x"]
#	   ["y"]
#          ["nodur"]	... les �v�nements eux-m�mes
#	   ["actif"]	marqueur d'activit� (0/1) 	
#	   ["s"]	(optionnel) marqueur de s�lection (voir wev())

# Sc�nes et collections d'�v�nements:
#------------------------------------
# ... voir data.k



################################################################################################
########			                         #######################################
########  Projection et partition: ProjCer & ProjSeg     #######################################
########			                         #######################################
################################################################################################

function CoreModes(ch, ne, pan, dist) # au coeur de la projection, dans ProjCer et ProjSeg 
{
	if (Ev[ch][ne]["script"] != "") 
		efunction(Ev[ch][ne]["script"])(Ev[ch][ne],pan,dist,ch,ne)	# script

	if ((ph = Ev[ch][ne]["nodur"]) == '') return ('' ) # la suite seulement si ph non vide

	if (ch <= 16)	# Canal MIDI affect� � un instrument d�termin�
	{
	  ph.vol += efunction(Volume[ch])(ph, pan, dist, ch)			# volume
	  ph.dur += efunction(Dur[ch])(ph, pan, dist, ch)			# dur�e

	  if ((ph.dur == 0) || (ph.vol <= SILENCE)) ph =''		 # rien
	  else {
	    ph.pitch += efunction(Pit[ch])(ph, pan, dist, ch)			# pitch
	    ph = controller(ch,0x0a,efunction(Pan[ch])(ph, pan, dist, ch)) | ph	# pan
	    ph = efunction(PB[ch])(ph, pan, dist, ch) | ph			# pitch bend

	    if (In[ch]==1) {ph = Ev[ch]["PAC"]+ph; In[ch]=0}	# r�initialisation
	  }
	}  

	else	        # Canal composite virtuel G�oMaestro
	{			
	   for (qc=1; qc <=16; qc++)		   # op�rations sur les canaux
	   if (sizeof(cut(ph,CUT_CHANNEL,qc))>0)   #  MIDI r�quisitionn�s   
	   {
	     ph.vol += efunction(Volume[ch])(ph, pan, dist, ch)			# volume
	     ph.dur += efunction(Dur[ch])(ph, pan, dist, ch)			# dur�e

	     if ((ph.dur == 0) || (ph.vol <= SILENCE)) ph =''			 # rien
	     else {
	       ph.pitch += efunction(Pit[ch])(ph, pan, dist, ch)			# pitch
	       ph = controller(qc,0x0a,efunction(Pan[ch])(ph, pan, dist, ch)) | ph	# pan
	       ph = efunction(PB[ch])(ph, pan, dist, ch, qc) | ph			# pitch bend     

	       In[qc] = 1      # il y a eu un In(vit�/tru) dans le canal qc !	   
	     }
	   }
	}

	return (ph)
}

################################################################################################
function ProjCer(ch,cercle,pdep,duree,ntour,...) 
#
#	projette les �v�nements sur un cercle et le parcourt ntour fois
#
# ch: canal MIDI �cout�
# cercle: cercle de projection des partitions
# pdep: point d�finissant le rayon de d�part (pas forc�ment sur le cercle)
# duree: duree d'un tour
# ntour: nombre de tour (si n�gatif, sens inverse des aiguilles d'une montre)
# ... est pour t0: temps offset (d�part des partitions) et region
################################################################################################
{
#  initialisation:
if (nargs()==5) {t0=0} else {t0=argv(5)}	
noregion = 0
if (nargs()==7) {region = argv(6)} else (noregion = 1)

xc = cercle["c"]["x"]
yc = cercle["c"]["y"]
rc = cercle["r"]

unsur2pi = pow(2*Pi,-1)
sens = Signe(ntour)		# -1 (sens trigo) ou +1 (sens horloge)
ntour = ntour*sens		# (valeur absolue)

theta0 = Getpolar(pdep["x"]-xc, pdep["y"]-yc)["theta"]

In = []		# sert � g�rer l'intrusion des canaux G�oMaestro dans les canaux d�di�s


#  boucle principale: 
#####################
	
	resph1 = ''

	for (ne=1 ; ne<=Ev[ch][0] ; ne++)			# on fait d�filer la sc�ne...
	{
	   if (Ev[ch][ne]["actif"])			# filtrage des �v�nements actifs
	   {
	      x = Ev[ch][ne]["x"]
	      y = Ev[ch][ne]["y"]

	      if ( (noregion) || (Region(x,y,ch,region)) )		
	      {
		polaire = Getpolar(x-xc,y-yc)		# pos. angulaire (/centre)	
		
		if (polaire["r"] > 0)	# sinon le point est au centre: ignor�
		{		
		  thetan = polaire["theta"]		
		  if (sens == 1)				# sens horloge
		   { pt = 1-Mod2Pi(thetan - theta0)*unsur2pi }
		  else
		   { pt = Mod2Pi(thetan - theta0)*unsur2pi }
		   
		  dist = sqrt(pow(x-xc,2)+pow(y-yc,2))-rc
		  pan = Signe(dist)*sens*(-1)	   
		  dist = Abs(dist)
		
		  ajout = CoreModes(ch, ne, pan, dist)  # les calculs sont l�...

		  ajout.time += pt*duree + t0

		  resph1 = resph1|ajout	
		}
	      }
	   }
	}

	resph = resph1
	resph.length = duree
	if (ntour >=2){
	   for (n=1; n<ntour; n++)
	       {resph = resph | delay(resph1, n*duree)}
	   resph.length = duree
	}

	if (ch <= 16) resph.chan = ch
	reslig = ["ph" = resph, 0 = t0, 1 = ntour*duree+t0]
	return (reslig)  
}

################################################################################################


##
# Fonctions pan... ("pantype")
#
# elles effectuent le test (droite ou gauche ?)
# pour une cible x,y suivant le type de segment
#
# a, b pour y = ax + b (�quation du segment de projection)	
# xd, yd pour les cas particuliers
#
# renvoie -1 (gauche) ou +1 (droite)
#
###########################################################
function panhaut(x, y, xd, yd, a, b)
{	if (x < xd) {return (-1)} else {return (1)}
}
function panbas(x, y, xd, yd, a, b)
{	if (x > xd) {return (-1)} else {return (1)}
}
function pandroite(x, y, xd, yd, a, b)
{	if (y > yd) {return (-1)} else {return (1)}
}
function pangauche(x, y, xd, yd, a, b)
{	if (y < yd) {return (-1)} else {return (1)}
}
function panversgauche(x, y, xd, yd, a, b)
{	if (y > a*x+b) {return (-1)} else {return (1)}
}
function panversdroite(x, y, xd, yd, a, b)
{	if (y < a*x) {return (-1)} else {return (1)}
}



##
# Fonctions Tin... ("testin")
#
#	utilis�e par ProjSeg
# 	pour s'adapter au type de segment
#
###############################################
function Tinvertical(x ,y, xd, yd, xf, yf)
{	
	res = ["x" = xd, "y" = y, "p" = (y-yd)*pow((yf-yd),-1)]
	return (res)
}
function Tinhorizontal(x ,y, xd, yd, xf, yf)
{
	res = ["x" = x, "y" = yd, "p" = (x-xd)*pow((xf-xd), -1)]
	return (res)
}
function Tinqcq(x ,y, xd, yd, xf, yf)
{
	a = (yf-yd)*pow((xf-xd),-1)
	b = yd-a*xd

	if (x == a*y + b)
	{ xx = x
	  yy = y
	}
	else
	{ xx = (x+a*y-a*b)*pow(1+a*a,-1)
	  yy = a*xx + b
	}

	res = ["x" = xx, "y" = yy, "p" = (xx-xd)*pow((xf-xd),-1)]
	return (res)
}


################################################################################################
function ProjSeg(ch, point1, point2, duree, ...) 
#
#	projette les �v�nements sur un segment, 
#		repr�sentant une dur�e duree, � partir de t0    (m�thode rapide) 
#
# ch: MIDI channel �cout�
# point1, point2: points de d�part et d'arriv�e
# duree: dur�e du segment
# ... est pour t0: temps offset (par d�faut: 0) et region
################################################################################################
{

#  initialisation:
if (nargs()==4) {t0=0} else {t0=argv(4)}	
noregion = 0
if (nargs()==6) {region = argv(5)} else (noregion = 1)
resph = ''			

xd = point1["x"]
yd = point1["y"]
xf = point2["x"]
yf = point2["y"]

aa = (yf-yd)*pow((xf-xd),-1)	# y = aa*x + bb �quation de la droite/segment
bb = yd-xd*aa


#  d�termination du type de segment:

if (xd == xf) {				# cas: segment vertical
   if (yf > yd)				#     ... montant
   {testin = Tinvertical
    pantype = panhaut}
   else					#     ... descendant
   {testin = Tinvertical
    pantype = panbas}
}
else {
   if (yd == yf) {			# cas: segment horizontal
      if (xf > xd)			#     ... droite
      {testin = Tinhorizontal
       pantype = pandroite}
      else				#     ... gauche
      {testin = Tinhorizontal
       pantype = pangauche}
   }
   else {				# cas: segment quelconque
      testin = Tinqcq
      if (xf > xd)			#     ... dirig� � droite
      {pantype = panversdroite}
      else				#     ... dirig� � gauche
      {pantype = panversgauche}
   }
}

In = []	 # sert � g�rer l'intrusion des canaux G�oMaestro dans les canaux d�di�s

#  boucle principale:
#####################

	for (ne=1 ; ne<=Ev[ch][0] ; ne++)			# on fait d�filer la sc�ne...
	{
	  if (Ev[ch][ne]["actif"])			# filtrage des �v�nements actifs
	  {
		x = Ev[ch][ne]["x"]
		y = Ev[ch][ne]["y"]
		
		if (noregion) {				# gestion des r�gions
		   pro = testin(x,y,xd,yd,xf,yf)
		   p = pro["p"]
		}
		else{
		   if (Region(x,y,ch,region)){
			pro = testin(x,y,xd,yd,xf,yf)
			p = pro["p"]
		   }
		   else p=-1				# .. si ev pas dans r�gion
		}
   
		if ((p>=0) && (p<=1))		# Ev dans zone d'�coute ?
		{
		  dist = sqrt(pow(x-pro["x"],2)+pow(y-pro["y"],2))	# � quelle distance ?
		  pan = pantype(x,y,xd,yd,aa,bb)			# de quel c�t� ?
	
		  ajout = CoreModes(ch, ne, pan, dist)  # les calculs sont l�...

		  ajout.time += p*duree+t0			   

	 	  resph = resph|ajout
		}
          }
	}
	if (ch <=16) resph.chan = ch
	reslig.length = duree

	reslig = ["ph" = resph, 0 = t0, 1 = duree+t0]
	return (reslig)  
}




##############################################################################################
########							  ############################
########  Projection et partition: fonctions de plus haut niveau  ############################
########							  ############################
##############################################################################################

# emploi du param�tre: duree
#
#	alors que dans ProjSeg et ProjCer, duree est une dur�e
#	effective mesur�e en unit�s KeyKit (b= 1 beat = Clicks unit�s), pour les
#	fonctions de plus haut niveau trois adressages sont possibles:
#
# duree = 0   par d�faut, mode relatif (CPCM clicks par cm)
#	       (pour CPCM = seconds(1), le d�faut est donc d'une seconde par centim�tre)
# duree < 0   mode relatif, en |duree|*CPCM
#	      (donc duree<-1 : ralentissement, 0>duree>-1 : acc�l�ration
#	       et duree=-1 �quivalent � duree=0 )
# duree > 0   mode absolu (nbe de clicks) identique � l'emploi dans ProjSeg et ProjCer 
#
# Remarque: duree est r�percut� dans chaque appel de EcouteC() ou Ecoute()
#	    en mode absolu, si duree = 1000, dans Echelle() chaque barreau aura une duree de 1000
#	    � l'oppos�, le mode relatif respecte les tailles relatives des segments et cercles



################################################################################################
#
# Fonctions de haut niveau bas�es sur ScanCer:
#
#  (les ...  pour duree, t0, region)
#
##############################################

function EcouteC(cer,d,nT,...)	# Projection simple sur cercle (cer)
				# EcouteC(cercle, point de d�part, nbe tours (sign�), duree, t0)
{
	if (nargs()==3) {duree = 0} else {duree =argv(3)}	
	if (nargs()<5) {t0=0} else {t0=argv(4)}	
	if (nargs()<6) {region = Tout} else {region = argv(5)}	

	if (duree == 0) { duree = CPCM*Peri(cer) }	    # valeur par d�faut (CPCM)
	else { 
	 if (duree < 0) { duree = -1*duree*CPCM*Peri(cer)}  # mode relatif (*CPCM)
	}	

	res = ["rac" = ["cer" = cer, "nT" = nT], "id"= "EcouteC"]

	cph1 = ''
	for (ch=1;ch<=NbCan;ch++){
	    lin = ProjCer(ch, cer, d, duree, Signe(nT), t0, region)
	    cph1 = cph1 | lin["ph"]	
	}
	realdur = lin[1]-t0
	cph = cph1
	nT = Abs(nT)

	if (nT >=2){
	   for (n=1; n<nT; n++)
	       {cph = cph | delay(cph1, n*realdur)}
	}
	res["paras"] = ["region" = region]
	res["ph"] = cph
	res[ 0 ] = t0
	res[ 1 ]= nT*realdur+t0
	return (res)
}

################################################################################################


function Spiro(cer,ray,sens,tht0,dthet,nC,pdep,...)	# Spirographe
			# Spiro(cercle des centres, rayon, sens (1 ou -1), theta0 (sign�), 
			# deltatheta, nbe de cercles, pt d�part)
{
	if (nargs()==7) {duree = 0} else {duree = argv(7)}	
	if (nargs()<9) {t0=0} else {t0=argv(8)}	
	if (nargs()<10) {region = Tout} else {region = argv(9)}	

	xc = cer["c"]["x"]
	yc = cer["c"]["y"]
	rc = cer["r"]

	res = ["inter"= [0= nC], "id"= "Spiro"]

	spres = ''
	tn = t0
	for (n=1; n<=nC; n++)
	{
		dir = Setpolar(rc, tht0 + (n-1)*dthet )
		centre = ["x"= dir["x"]+xc, "y"= dir["y"]+yc]
		crcle = ["c"=centre, "r"=ray]
		
		lin = EcouteC(crcle, pdep, sens, duree, tn, region)
		
		spres = spres | lin["ph"]
		tn = lin[1]

		res["inter"][n] = ["cer" = crcle,  "s" = sens]
	}
	res["paras"] = ["region" = region]
	res["rac"] = ["cer" = crcle,  "s" = sens]
	res["ph"] = spres
	res[ 0 ] = t0
	res[ 1 ]= tn
	
	return (res)
}


################################################################################################

function Onde(cer1, cer2, nbecers, sens, pdep, ...)	# d'un cercle � l'autre
		    # Onde(cercle d�part, cercle d'arriv�e, nbe de cercles, 
		    # point de d�part pour chaque cercle, duree, t0)
{
	if (nargs()==5) {duree = 0} else {duree = argv(5)}	
	if (nargs()<7) {t0=0} else {t0=argv(6)}
	if (nargs()<8) {region = Tout} else {region = argv(7)}	

	x1 = cer1["c"]["x"]
	y1 = cer1["c"]["y"]
	x2 = cer2["c"]["x"]
	y2 = cer2["c"]["y"]
	r1 = cer1["r"]
	r2 = cer2["r"]
	unsur = pow(nbecers-1,-1)
	
	tn = t0
	ores = ''
	res = ["inter" = [0 = nbecers], "id" = "Onde"]
	for (n = 1; n <= nbecers; n++)
	{
		centre = ["x"= x1+(n-1)*(x2-x1)*unsur, "y"= y1+(n-1)*(y2-y1)*unsur]  
		rayon = r1+(n-1)*(r2-r1)*unsur
		crcle = ["c" = centre, "r" = rayon]				

		lin = EcouteC(crcle, pdep, sens, duree, tn, region)
		
		ores = ores | lin["ph"]
		tn = lin[1]

		res["inter"][n] = ["cer" = crcle,  "s" = sens]
	}	
	res["paras"] = ["region" = region]
	res["rac"] = ["cer" = crcle,  "s" = sens]
	res["ph"] = ores
	res[ 0 ] = t0
	res[ 1 ]= tn
	
	return (res)
}


################################################################################################
#
# Fonctions de haut niveau bas�es sur ProjSeg:
#  
#  (les ...  pour duree, t0, region)
#
##############################################


function Ecoute(a,b,...)	# Projection simple (� fT=Clicks par d�faut) sur segment (a,b)
				# Ecoute(a, b, duree, t0)
				# gaffe au format de dur�e (ex: -1 �quivalent � 0)
{


	if (nargs()==2) {duree=0} else {duree=argv(2)}	
	if (nargs()<4) {t0=0} else {t0=argv(3)}	
	if (nargs()<5) {region = Tout} else {region = argv(4)}	

	if (duree == 0) { duree = CPCM*Dist(a,b) }		  # valeur par d�faut (CPCM)
	else if (duree < 0) { duree = Abs(duree)*CPCM*Dist(a,b)}  # mode relatif (*CPCM)
		
	segph = ''
	for (ch=1;ch<=NbCan;ch++){
	    lin = ProjSeg(ch, a, b, duree, t0, region)
	    segph = segph | lin["ph"]	
	}

	seg = ["ph" = segph, 0 = lin[0], 1 =lin[1], "id"= "Ecoute"]
	seg["paras"] = ["region" = region]
	seg["rac"] = ["A" = a, "B" = b]

	return (seg)
}


################################################################################################


function Echelle(a1, a2, b1, b2, nb, ...)	# Echelle � N barreaux appuy�s sur deux segments
{
	if (nargs()==5) {duree = 0} else {duree = argv(5)}	
	if (nargs()<7) {t0=0} else {t0=argv(6)}	
	if (nargs()<8) {region = Tout} else {region = argv(7)}	

	unsurnm = pow(nb-1, -1)		# 1/(N-1)
	te = t0
	resph = ''

	bars= ["inter"= [0= nb], "id"="Echelle", "rac"= ["A"=a2, "B"=b2], "paras"= ["duree"= duree]]

	for (n=0; n<nb; n++)
	{
		a = ["x" = a1["x"]+n*(a2["x"]-a1["x"])*unsurnm	]
		a["y"] = a1["y"]+n*(a2["y"]-a1["y"])*unsurnm	
		b = ["x" = b1["x"]+n*(b2["x"]-b1["x"])*unsurnm	]
		b["y"] = b1["y"]+n*(b2["y"]-b1["y"])*unsurnm	

		bar = Ecoute(a,b,duree,te,region)

		te = bar[1]

		bars["inter"][n+1] = ["A" = a, "B"= b, 0 = bar[0], 1 = bar[1]]

		resph = resph | bar["ph"]
	}

	bars["paras"] = ["region" = region]
	bars["ph"] = resph
 	bars[0] = t0
 	bars[1] = te

	return (bars)
}


################################################################################################


function AversB(a,b,long,ouvert,...)	# ligne bris�e de A vers B 
					# (longueur des segments et angle de vis�e)
{
	if (nargs()==4) {duree=0} else {duree=argv(4)}	
	if (nargs()<6) {t0=0} else {t0=argv(5)}	
	if (nargs()<7) {region = Tout} else {region = argv(6)}	

	segs = ["inter" = [0=0], "id"="AversB", "paras" = ["region" = region]]
	resph = ''
	te = t0
	n = 0
	while (Dist(a,b) > long)
	{
		ab = Getpolar(b["x"]-a["x"], b["y"]-a["y"])	# vecteur AB
		theta = Mod2Pi((rand(100)-50)*0.01*ouvert + ab["theta"])

		a2 = Setpolar(long, theta)
		a2 = ["x" = a2["x"]+a["x"], "y"= a2["y"]+a["y"]]
		seg = Ecoute(a,a2,duree,te,region)

		te = seg[1]
		n += 1
		segs["inter"][n] = ["A"= a, "B"= a2, 0= seg[0], 1= seg[1]]

		resph |= seg["ph"]
		a = a2
	}
	seg = Ecoute(a2,b,duree,te,region)
	n += 1
	segs["inter"][n] = ["A"= a2, "B"= b, 0= seg[0], 1= seg[1]]

	resph |= seg["ph"]

	segs["inter"][0] = n	

	segs["ph"]= resph
	segs[0] = t0
	segs[1] = seg[1]

	return (segs)
}

################################################################################################

function Helice(centre, ray, theta0, deltath, nT, ...)	# Diam�tre tournant
		# centre, rayon, angle initial, pas angulaire, nbe tours (signe -> sens)
{
	if (nargs()==5) {duree=0} else {duree=argv(5)}	
	if (nargs()<7) {t0=0} else {t0=argv(6)}	
	if (nargs()<8) {region = Tout} else {region = argv(7)}	

	th = t0
	resph1 = ''

	xc = centre["x"]
	yc = centre["y"]

	sens = Signe(nT)
	nT *= sens
	nb = integer(2*Pi*pow(deltath,-1))

	bars = [0 = t0, "paras" = ["region" = region], "inter"= [0= nb], "id"= "Helice"]

	for (n=0; n<nb; n++)			# pour un tour
	{
		theta = Mod2Pi(theta0 + sens*n*deltath)

		a = Setpolar(ray,theta)
		b = Setpolar(ray,Mod2Pi(theta + Pi))

		a = ["x" = xc + a["x"], "y" = yc + a["y"] ]
		b = ["x" = xc + b["x"], "y" = yc + b["y"] ]

		bar = Ecoute(a,b,duree,th,region)
		
		bars["inter"][n+1] = ["A"= a, "B"= b, 0= bar[0], 1= bar[1]]

		th = bar[1]
		resph1 = resph1 | bar["ph"]
	}

	resph = resph1
	if (nT > 1)				# les nT-1 autres tours
	{
		for (n=1; n<nT; n++)
		    { resph = resph | delay(resph1, n*th) }
	}

	bars["ph"] = resph 
	bars[1] = nT*th

	return (bars)
}

################################################################################################

function Brown(d1, d2, amp, dureerrance, reg,...)	# segment aux extr�mit�s errantes
{
	if (nargs()==4) {region_auto = Tout} else {region_auto = reg}	
	if (nargs()<6) {duree=0} else {duree=argv(5)}	
	if (nargs()<7) {t0=0} else {t0=argv(6)}		
	if (nargs()<8) {region = Tout} else {region = argv(7)}
	

	frags = ["inter" = [0=0], "id"="Brown", "rac" = []]

	resph = ''
	n = 1
	for (tb = t0; tb < dureerrance; n++)
	{
		frag = Ecoute(d1, d2, duree, tb, region)
		tb = frag[1]
		resph = resph | frag["ph"]

		frags["inter"][n] = ["A" = d1, "B" = d2, 0 = frag[0], 1 = frag[1]]

		frags["rac"]["Ax"] = d1["x"]	
		frags["rac"]["Ay"] = d1["y"]		
		frags["rac"]["Bx"] = d2["x"]	
		frags["rac"]["By"] = d2["y"]	

		for (fin = 0; fin == 0; fin = RegionPoint(d,region_auto)) {
			mouv = Setpolar(amp, rand(0,100)*0.02*Pi)		# brownien 1
			d = ["x"= d1["x"]+mouv["x"],"y"= d1["y"]+mouv["y"] ]
		}
		d1 = d
		for (fin = 0; fin == 0; fin = RegionPoint(d,region_auto)) {
		        mouv = Setpolar(amp, rand(0,100)*0.02*Pi)		# brownien 2
		        d = ["x"= d2["x"]+mouv["x"],"y"= d2["y"]+mouv["y"] ]
		}
		d2 = d
	}

	frags["paras"] = ["region" = region, "zone" = region_auto]
	frags["inter"][0] = n-1
	frags["ph"] = resph 
	frags[0] = t0 
	frags[1] = tb


	return (frags)
}

################################################################################################


function EntrePistes(p1, p2, ...)	  # Echelle � ? barreaux appuy�s sur deux pistes
{
	if (nargs()==2) {duree = 0} else {duree = argv(2)}	
	if (nargs()<4) {t0=0} else {t0=argv(3)}	
	if (nargs()<5) {region = Tout} else {region = argv(4)}	

	te = t0
	resph = ''
	nb = Minimum(p1[0], p2[0])

	bars= ["inter"= [0= nb], "id"="EntrePistes", "paras"= ["duree"= duree]]

	for (n=1; n<=nb; n++)
	{
		a = ["x"= p1[n]["x"], "y"= p1[n]["y"]]
		b = ["x"= p2[n]["x"], "y"= p2[n]["y"]]

		bar = Ecoute(a,b,duree,te,region)

		te = bar[1]

		bars["inter"][n] = ["A" = a, "B"= b, 0 = bar[0], 1 = bar[1]]

		resph = resph | bar["ph"]
	}

	bars["paras"] = ["region" = region]
	bars["ph"] = resph
 	bars[0] = t0
 	bars[1] = te

	return (bars)
}


################################################################################################


function Vague(p1, p2, long, ouvert, ...)	 
			     # Echelle bris�e (AversB) � ? barreaux appuy�s sur deux pistes
{
	if (nargs()==4) {duree = 0} else {duree = argv(4)}	
	if (nargs()<6) {t0=0} else {t0=argv(5)}	
	if (nargs()<7) {region = Tout} else {region = argv(6)}	

	te = t0
	resph = ''
	nb = Minimum(p1[0], p2[0])

	bars= ["inter"= [0= nb], "id"="Vague", "paras"= ["duree"= duree]]

	for (n=1; n<=nb; n++)
	{
		a = ["x"= p1[n]["x"], "y"= p1[n]["y"]]
		b = ["x"= p2[n]["x"], "y"= p2[n]["y"]]

		bar = AversB(a,b,long,ouvert,duree,te,region)

		te = bar[1]

		bars["inter"][n] = ArCopy(bar["inter"])

		resph = resph | bar["ph"]
	}

	bars["paras"] = ["region" = region]
	bars["ph"] = resph
 	bars[0] = t0
 	bars[1] = te

	return (bars)
}


################################################################################################

function PerspectiveAB(a, b, theta,...)
{
	if (nargs()==3) {duree = 0} else {duree = argv(3)}	
	if (nargs()<5) {t0=0} else {t0=argv(4)}	
	if (nargs()<6) {region = Tout} else {region = argv(5)}	

	r = 0.5*Dist(a,b)
	mab = ["x"= 0.5*(b["x"]+a["x"]), "y"= 0.5*(b["y"]+a["y"])]  # milieu de (a,b)

	# a relativement � mab:
	am = Getpolar(a["x"]-mab["x"], a["y"]-mab["y"])
	# bc "projection" de b sur le cercle AB faisant un angle theta avec mab
	bc = Setpolar(r*(1.005), Mod2Pi(am["theta"]+theta))
	bc["x"] += mab["x"]
	bc["y"] += mab["y"]	

	return(Ecoute(a, bc, duree, t0, region))
}
	
function CercleRythm(a, b, npart, ...)
{
	if (nargs()==3)				# traitement particulier de la dur�e ici... 
	   {duree = Dist(a,b)*CPCM} 
	else					# le mode relatif est adapt�,
	{					# le mode absolu pr�serv�.
	   if ((duree = argv(3)) < 0)
	      duree = Abs(duree)*Dist(a,b)*CPCM
	}	

	if (nargs()<5) {t0=0} else {t0=argv(4)}	
	if (nargs()<6) {region = Tout} else {region = argv(5)}	

	res = [0= t0, "inter" = [0= npart], "id"="CercleRythm"]

	resph = ''
	te = t0
	for (n=1; n<=npart; n++)
	{ 
	  pn = PerspectiveAB(a, b, n*2*Pi/(npart+1), duree, te, region)	  
	  resph |= pn["ph"]
	  te = pn[1]

	  res["inter"][n] = ["A"= pn["rac"]["A"], "B"= pn["rac"]["B"], 0= pn[0], 1= te] 
	}  

	res["ph"] = resph
	res[1] = te

	return (res)
}







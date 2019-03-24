MODULE Lines;
(* Systemsoftware WS 98/99, Oliver Knoll, Raphael Huber *)

(* implementiert Linien - die Linienkoordinaten sind "Weltkoordinaten", bei einer DrawMsg rechnen die Linien *)
(* diese Koordinaten selbstaendig in Screenkoordinaten um *)

(* w und h sind immer positiv (dies vereinfacht die Berechnungen in SelectableLine() ), d.h. x und y sind beim *)
(* Erschaffen einer Linie entsprechend zu setzen *)

IMPORT OliObjects, FortiFrames, Display, Oberon, Viewers;

CONST
	tol = 2;	(* Toleranz: 2 Pixel darf man danebenklicken *)

TYPE
	Line = POINTER TO LineDesc;
	LineDesc = RECORD(OliObjects.ObjectDesc)
	END;
	
	LineMethod = OliObjects.Method;

VAR
	linemethod: LineMethod;	(* globale Variable, da Methoden fix sind *)
	
PROCEDURE CopyLine(from, to: OliObjects.Object);
(* kopiert eine Linie: from ist die Originallinie MyLine, to ist eine vorgaengig mit MyLine.do.new() erschaffene Linie *)

VAR

BEGIN
	to(Line)^:= from(Line)^
END CopyLine;

PROCEDURE SelectableLine(line: OliObjects.Object; x, y: INTEGER): BOOLEAN;
(* entscheidet, ob ein Mausklick mit Toleranz tol die Linie selektiert *)

VAR

BEGIN
	RETURN (x >= line.x - tol) & (x <= line.x + line.w + tol) & (y >= line.y - tol) & (y <= line.y + line.h + tol)

END SelectableLine;

PROCEDURE HandleLine(line: OliObjects.Object; VAR msg: OliObjects.Message);
(* interpretiert die Messages, welche von FortiFrames aus kommen *)
(* im Moment wird nur die DrawMsg interpretiert *)

VAR
	u, v, w, h: INTEGER;	(* Screen-Koordinaten *)
	
BEGIN
	IF msg IS FortiFrames.DrawMsg THEN
		WITH msg: FortiFrames.DrawMsg DO
			WITH line: Line DO
				u:= line.x + msg.f.x;	(* Screenkoordinaten berechnen *)
				v:= line.y + msg.f.y;
				w:= line.w;
				h:= line.h;
				CASE msg.mode OF
					OliObjects.draw:	IF line.selected THEN
													Display.ReplPatternC(msg.f, line.col, Display.grey0, u, v, w, h, u, v, Display.replace)
												ELSE
													Display.ReplConstC(msg.f, line.col, u, v, w, h, Display.replace)
												END;
					|	OliObjects.select:	Display.ReplPatternC(msg.f, line.col,  Display.grey0, u, v, w, h, u, v, Display.replace)
					|	OliObjects.normal:	Display.ReplConstC(msg.f, line.col, u, v, w, h, Display.replace)
					|	OliObjects.erase:	Display.ReplConstC(msg.f, Display.black, u, v, w, h, Display.replace)
				END
			END
		END
	END	(* Ignoriere andere Messages *)
END HandleLine;
					
PROCEDURE NewLine(): OliObjects.Object;
(* retourniert eine neue Linie und initialisiert Methoden-Rekord *)

VAR
	line: Line;
	
BEGIN
	NEW(line);
	line.do:= linemethod;
	RETURN line
END NewLine;

(* --- User Prozeduren ----------------------------------------------- *)

PROCEDURE MakeLine*();
(* Zeichnet Linie im mit dem Stern markierten Frame. Diese ist anschliessend selektiert *)
(* eine Linie wird von mark0 nach mark1 gemalt, wobei mark0 anschliessend Position *)
(* von mark1 einnimmt und mark1 verschwindet. *)

VAR
	line: Line;
	w, h: INTEGER;
	rmMsg: FortiFrames.RestoreMarksMsg;

BEGIN
	IF ~((FortiFrames.mark0.set) & (FortiFrames.mark1.set)) THEN
		(* eventuell hier noch Fehlermeldung ausgeben *)
		RETURN
	END;
	
	NEW(line);
	line.col:= OliObjects.color;
	line.selected:= TRUE;	(* Linie soll selektiert gemalt werden *)
	line.do:= linemethod;
	w:= FortiFrames.mark1.x - FortiFrames.mark0.x;
	h:= FortiFrames.mark1.y - FortiFrames.mark0.y;
	Viewers.Broadcast(rmMsg);	(* alte Markierungen werden geloescht *)

	(* jetzt bestimmen wir das x und y *)
	IF (ABS(w) > ABS(h)) THEN	(* male horizontale Linie *)
		IF (w < 0) THEN	(* w ist negativ -> vertausche die x *)
			FortiFrames.mark0.x:= FortiFrames.mark1.x;	(* mark0 geht an Pos. von mark1 *)
			line.x:= FortiFrames.mark0.x;
			line.y:= FortiFrames.mark0.y;
			line.w:= -1 * w;	(* Breite ist jetzt positiver Wert *)
			line.h:= 1;
			FortiFrames.mark1.set:= FALSE;	(* mark1 soll verschwinden *)
		ELSE	(* w ist schon positiv *)
			line.x:= FortiFrames.mark0.x;
			line.y:= FortiFrames.mark0.y;
			FortiFrames.mark0.x:= FortiFrames.mark1.x;	(* mark0 geht erst jetzt an Pos. von mark1 *)
			line.w:= w;
			line.h:= 1;
			FortiFrames.mark1.set:= FALSE	(* mark1 soll verschwinden *)
		END
	ELSE	(* male vertikale Linie *)
		IF (h < 0) THEN (* h ist negativ -> vertausche die y *)
			FortiFrames.mark0.y:= FortiFrames.mark1.y;	(* mark0 geht an Pos. von mark1 *)
			line.x:= FortiFrames.mark0.x;
			line.y:= FortiFrames.mark0.y;
			line.w:= 1;
			line.h:= -1 * h;	(* Hoehe ist jetzt positiver Wert *)
			FortiFrames.mark1.set:= FALSE;	(* mark1 soll verschwinden *)
		ELSE	(* h ist schon positiv *)
			line.x:= FortiFrames.mark0.x;
			line.y:= FortiFrames.mark0.y;
			FortiFrames.mark0.y:= FortiFrames.mark1.y;	(* mark0 geht erst jetzt an Pos. von mark1 *)
			line.w:= 1;
			line.h:= h;
			FortiFrames.mark1.set:= FALSE	(* mark1 soll verschwinden *)
		END
	END;
	
	(* die folgene Prozedur kuemmert sich um das Einfuegen und Benachrichtigen aller Frames *)
	(* ausserdem werden dort alle anderen Objekte vorher deselektiert *)
	FortiFrames.InsertObject(FortiFrames.markedG, line)
END MakeLine;

BEGIN
	(* der Methodenrekord wird einmal initialisiert und ist somit fix *)
	NEW(linemethod);
	linemethod.new:= NewLine;
	linemethod.copy:= CopyLine;
	linemethod.selectable:= SelectableLine;
	linemethod.handle:= HandleLine;
END Lines.
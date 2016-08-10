/*
[INFO]

NAME = Batch Import DropData
VERSION = 3.0.0
AUTHOR = MastaMan
DEV = SightLine Vision
HELP = 


[1.0.0]
	
	* First Release	=	

[2.0.0]

	* Bug fixes...=

[2.5.0]

	* Auto close import window=

[3.0.0]

	* Code optimization=
	* Bug fixes=
	* Adopt for new Scripts Launcher=
[3.0.1]		
	+Added: Support *.dae type=
	* Find files in all directories and root directory=
	
[ABOUT]

		- Import all *.3DS/*.dae data from subfolder=
		- Set full path for bitmaps=
		- Attach all parts in to one mesh=
		- Split result to several files=
		- Clear MultiMaterial=
		- Clear mesh ID=
		- Auto Smooth=
		- Auto Weld vertcies	=
		- Check name conflict=
		- Delete dublicate geometry=
		- Show/Hide textures in viewport=


[SCRIPT]
*/

fileTypes = #("*.3DS", "*.dae")


fn getScriptInfo s releaseInfo: "" =
(		
	if(releaseInfo != "") do
	(
		r = getINISetting s releaseInfo
		return r
	)
	
	v = getINISetting s "INFO" "VERSION"
	a = getINISetting s "INFO" "AUTHOR"
	n = getINISetting s "INFO" "NAME"
	o = getINISetting s "ABOUT"
	c = getINISetting s "INFO" "DEV"
	h = getINISetting s "INFO" "HELP"
	
	r = for i in (getINISetting s) where i != "ABOUT" and i != "SCRIPT" and i != "COPY" collect i
	
	return #(n, a, v, o, r, c, h)
)

fn parseToLine m = 
(
	if(m.count == 0) do return ""
	
	l = ""				
	for i in m do l += i + "\n"
	return l
)


try(closeRolloutFloater rBatchImport) catch()
global rBatchImport = newRolloutFloater "Batch Import DropData" 190 350

rollout BatchImport "Batch Import DropData" width:170 height:259
(
	button btnBrowse "Browse"  width:166 height:34
	group "Options"
	(
		checkbox chkTexturesFullPath "Use full path for textures" checked:true
		checkbox chkCreateOneMesh "Create one mesh"  checked:true
		checkbox chkDivideToParts "Split result to several files" checked:false
		checkbox chkWeldAndSmooth "Weld and Smooth mesh" checked:true
		checkButton chkShowTexturesViewport "Show textures in viewport"  width:152 height:20 checked:false
		edittext edtName ""  width:90 height:19 text:"BackDropData" across: 2 offset: [-5, 0]
		spinner spnCounter "_part" width:54 height:16 range:[0,1000,1] type:#integer scale:1 offset: [2, 0]		
	)
	
	button btnStartImport "Start Import" width:166 height:34 offset: [0, 10]
	progressBar pbStatus ""  width:160 height:12 color:(color 200 200 200) offset: [-5, 0]
	label lblStatusBar "Browse files" align: #left
	
	Timer tmrTimer "Timer" pos:[5,198] width:24 height:24 active:false
	Timer tmrTimer2 "Timer2" pos:[5,198] width:24 height:24 active:false interval: 50
	
	
	global szFolder = ""
	global szDirectories
	
	global MatIDCnt = 0
	global iCnt = 0
	global iCnt2 = 0
	global MatID = #()
	global MatIDOverflow = 1
	global szParts = #()
	global objectPos = #()
	global materialsViewport = #()
		
	global MatIDOverflowCnt = 500 /* Maximum Material ID */
	
	global settingsFile = ""
	
	fn disableUI x =
	(
		btnBrowse.enabled = x
		btnStartImport.enabled = x
		chkTexturesFullPath.enabled = x
		chkCreateOneMesh.enabled = x
		chkDivideToParts.enabled = x
		chkWeldAndSmooth.enabled = x
		spnCounter.enabled = x
		edtName.enabled = x
		--chkShowTexturesViewport.enabled = x
	)
	
	fn SelectedDir p =
	(
		p = filterString  p "\\"
		i = p.count

		return p[i]
	)
	
	fn useSettings b k p w =
	(	
		case w of
		(
			0:
			(
				s = getINISetting settingsFile b k
				case p of
				(
					"int": return s as integer
					"float": return s as float
					"bool": if s == "true" then true else false
					default: return s
				)
			)
			default: return setINISetting settingsFile b k (p as string)
		)
	)
	
	fn checkDialog = 
	(
		hwnd = dialogMonitorOps.getWindowHandle()
		if (uiAccessor.getWindowText hwnd == "Import Name Conflict") then 
		(
			uiAccessor.PressButtonByName hwnd "OK"
		)
		return true
	)
	
	fn AttachObj o =
	(
		undo off
		(
			x = for i in o where superclassof i == GeometryClass and classof i != TargetObject collect i
			
			j = 1
			
			while x.count > 1 do
			(				
				if(classOf x[j] != Editable_Poly) then  convertToPoly x[j]
									
				polyop.attach x[j] x[j+1]
				deleteItem x (j+1)
					
				j += 1
					
				if (j + 1) > x.count then j = 1  				
			)
		)
	
		CenterPivot x[1]
		x[1].wirecolor = gray
	)
	
	fn optimizeIDCount o =
	(	
		for i in o where superclassof i == GeometryClass and classof i != TargetObject do
		(	
			convertToPoly i
			m = 0
			PolyID = #()
			PolyNumID = #()
			szMaterial = #()
			
			if(classOf i.material == Multimaterial) then
			(
				szMaterial = for k in i.material collect k
			)
			else
			(
				append szMaterial i.material
			)
								
			for k in szMaterial do
			(
				m += 1
				
				if(k.diffuseMap != undefined) do
				(
					r = findItem MatID k.diffuseMap
					if(r == 0) then 
					(
						MatIDCnt += 1
						u = MatIDCnt + 1
						append MatID k.diffuseMap
					) else 
					(
						u = r + 1
					)
								
					
					if(chkTexturesFullPath.checked == true) do
					(					
						k.diffuseMap.filename =  szDirectories[iCnt] + (filenameFromPath k.diffuseMap.filename)
					)
												
								
					f_tmp = #()
					for f = 1 to i.numfaces do (if(polyop.getFaceMatID i f == m) do append f_tmp f)
			
					append PolyID f_tmp
					append PolyNumID u
				)
			)
						
			polyop.setFaceMatID i #all 1
			
			for z = 1 to PolyID.count do
			(
				polyop.setFaceMatID i PolyID[z] PolyNumID[z]
			)
		)
	
	)
	
	fn createAndAssignMaterial w =
	(
		backDropMultimaterial = multimaterial numsubs: (MatIDCnt + 1) name: ("BackDropData_" + w as string)
		backDropMultimaterial[1].diffuse = (color 145 148 108)

		for q = 1 to MatID.count do
		(
			backDropMultimaterial[q + 1].diffuseMap = MatID[q]
			backDropMultimaterial[q + 1].showInViewport = false --chkShowTexturesViewport.checked
		)

		geometry.material = backDropMultimaterial
	)
	
	global iCnt3 = 1
	fn showTexturesViewport x =
	(
		lblStatusBar.caption = "Wait process textures..."
		
		materialsViewport = #()
		
		for i in geometry do
		(
			if(classOf i.material == Multimaterial) then for a in i.material do append materialsViewport a else append materialsViewport i.material			 
		)
		
		pbStatus.value = 0.0
		tmrTimer2.active = false
		tmrTimer2.active = true
		iCnt3 = 1
		
		disableUI false
	)
		
	on tmrTimer2 tick do
	(		
		try(materialsViewport[iCnt3].showInViewport = chkShowTexturesViewport.checked)catch()
		
		iCnt3 += 1
		
		pbStatus.value = ((iCnt3 as float) / (materialsViewport.count as float)) * 100.0
		
		if(iCnt3 >= materialsViewport.count) do 
		(
			iCnt3 = 1
			pbStatus.value = 0.0
			lblStatusBar.caption = "Textures " + (if(not chkShowTexturesViewport.checked) then "un" else "") + "loaded!"
			disableUI true
			tmrTimer2.active = false			
		)
	)

	fn deleteClone =
	(
		objectToDelete = #()
		
		centerPivot geometry
		
		for i in geometry do
		(
			if((findItem objectPos i.pos) != 0) then
			(
				append objectToDelete i
			)
			else
			(
				append objectPos i.pos
			)
		)
		
		delete objectToDelete
		objectToDelete = #()
		objectPos = #()
	)
	
	fn addWeldAndSmooth =
	(
		m1 = Vertex_Weld threshold: 0.01
		m2 = Smooth autosmooth: true preventIndirect: false threshold: 45

		addModifier geometry m1
		addModifier geometry m2
		
		convertToPoly geometry
	)
	
	fn processAndSave=
	(
		n = edtName.text + "_part" + (MatIDOverflow + (spnCounter.value - 1)) as string
			
		szFileName = szFolder + "\\" + n + ".max"

		createAndAssignMaterial MatIDOverflow
		deleteClone()
		if(chkCreateOneMesh.checked == true) then 
		(
			AttachObj geometry
			geometry[1].name = n
		)
		else
		(
			for i = 1 to geometry.count do
			(
				geometry[i].name = n + "_" + i as string
			)
		)
		if(chkWeldAndSmooth.checked == true) do addWeldAndSmooth()
				
		saveNodes geometry szFileName quiet:true
			
		append szParts szFileName
	)
		
	on BatchImport open do
	(
		d = getFilenamePath  (getThisScriptFilename())
		n = filenameFromPath (getThisScriptFilename())			
		settingsFile = d + @"ini\" + (sysInfo.username) + "_" + n + ".ini"
				
		
		szFolder = useSettings "FILE" "FOLDER" "string" 0
		chkTexturesFullPath.checked = useSettings "CHECBOX" "TEXTURESFULLPATH" "bool" 0
		chkCreateOneMesh.checked = useSettings "CHECBOX" "CREATEONEMESH" "bool" 0
		chkDivideToParts.checked = useSettings "CHECBOX" "DIVIDETOPARTS" "bool" 0
		chkWeldAndSmooth.checked = useSettings "CHECBOX" "WELDANDSMOOTH" "bool" 0
		chkShowTexturesViewport.checked = useSettings "CHECBOX" "SHOWTEXTURESVIEWPORT" "bool" 0
		n = useSettings "FILE" "NAME" "string" 0
		if(n != "") do edtName.text = n		
	)
	on BatchImport close do
	(
		enableSceneRedraw()
	)
	on btnBrowse pressed do
	(
		szFolder = getSavePath caption:"Browse"	 initialDir: szFolder
		if(szFolder != undefined and szFolder != "") do
		(
			btnBrowse.caption = SelectedDir szFolder
			useSettings "FILE" "FOLDER" szFolder 1
			lblStatusBar.caption = "Selected " + btnBrowse.caption
		)				
	)
	on btnStartImport pressed do
	(
		if(szFolder == undefined and szFolder == "") do
		(
			MessageBox "Please browse folder!"
			return 0
		)
		
		szDirectories = GetDirectories (szFolder + "\*")
		append szDirectories szFolder
		
		/*
		if(szDirectories[1] == undefined or szDirectories[1] == "") do 
		(
			MessageBox "Subfolder not found!"
			return 0
		)*/
		
		try(resetMaxFile #noPrompt)catch(resetMaxFile)
		
		lblStatusBar.caption = "Wait while importing..."
				
		tmrTimer.interval = 100
		tmrTimer.active = true
		
		disableUI false
		
		MatID = #()
		MatIDOverflow = 1
		iCnt = 0
		iCnt2 = 0
		
		disableSceneRedraw()
	)
	on chkTexturesFullPath changed x do useSettings "CHECBOX" "TEXTURESFULLPATH" x 1
	on chkCreateOneMesh changed x do useSettings "CHECBOX" "CREATEONEMESH" x 1
	on chkDivideToParts changed x do	useSettings "CHECBOX" "DIVIDETOPARTS" x 1
	on chkWeldAndSmooth changed x do useSettings "CHECBOX" "WELDANDSMOOTH" x 1
	on edtName changed t do useSettings "FILE" "NAME" t 1
	on chkDivideToParts changed x do 	useSettings "CHECBOX" "DIVIDETOPARTS" x 1
	on chkShowTexturesViewport changed x do
	(
		useSettings "CHECBOX" "SHOWTEXTURESVIEWPORT" x 1
		showTexturesViewport x
	)
	
	fn getFilesByType d = 
	(
		o = #()
		for t in fileTypes do
		(
			f = getFiles(d + @"\" + t)
			join o f
		)
		
		return o
	)
	
	on tmrTimer tick do
	(
		tmrTimer.active = false
		tmrTimer.interval = 1000
		
		iCnt += 1
		
		szFiles = getFilesByType szDirectories[iCnt]	
				
		iCnt2 += szFiles.count
					
		for i in szFiles where i != undefined do
		(
			try
			(
				dialogMonitorOps.enabled = true
				dialogMonitorOps.unRegisterNotification id:#importConflict
				dialogMonitorOps.registerNotification checkDialog id:#importConflict
				importFile i #noPrompt
				dialogMonitorOps.enabled = false
			)
			catch(importFile i #noPrompt)
						
			optimizeIDCount  selection
			s = selection[1]
			if(s != undefined) do s.name = timeStamp() as string
			
			if(MatIDCnt >= MatIDOverflowCnt) do
			(
				processAndSave()
					
				try(resetMaxFile #noPrompt)catch(resetMaxFile)
				
				MatIDOverflow += 1
				MatIDCnt = 0
				MatID = #()
				
				sleep 2
			)
		)
				
		pbStatus.value = ((iCnt as float) / (szDirectories.count as float)) * 100.0
		
		
		if(pbStatus.value >= 100.0) then
		(
			processAndSave()
				
			if(chkDivideToParts.checked == false)	 do
			(
				try(resetMaxFile #noPrompt)catch(resetMaxFile)
				
				for u in szParts do
				(
					mergeMaxFile u #select #MergeDups quiet: true
					deleteFile u
				)
				
				saveMaxFile (szFolder + "\\" + edtName.text) quiet:true				
			)
							
			btnBrowse.caption = "Browse"
			
			disableUI true
			
			if(iCnt2 == 0) do MessageBox "Not found *.3DS files!"
			
			iCnt = 0
				
			szParts = #()
			objectPos = #()
			
			enableSceneRedraw()
			
			shellLaunch szFolder ""
			
			lblStatusBar.caption = "Import done!"
			
			tmrTimer.active = false							
		)
		else
		(
			tmrTimer.active = true
		)
	)
	
)

rollout rAbout "About" 
(	
	label lblName "" 
	label lblVer "" 
	
	label lblAuthor "" height: 30
	label lblCopy ""  height: 30
	button btnHelp "Help" enabled: false
	
	fn getHelp run: false =
	(
		s = getThisScriptFilename()
		i = getScriptInfo s
		szHelp = (getFilenamePath s) + i[7]
		if(i[7] != "" and doesFileExist szHelp) do btnHelp.enabled = true
			
		if(run) do ShellLaunch szHelp ""
	)
	
	on btnHelp pressed do getHelp run: true
				
	on rAbout open do
	(		
		i = getScriptInfo (getThisScriptFilename())
			
		lblName.caption = i[1]
		lblAuthor.caption = i[2]
		lblVer.caption = i[3]
		lblCopy.caption = i[6]
		
		getHelp()
	)
)		

addRollout BatchImport rBatchImport rolledUp:false 
addRollout rAbout rBatchImport rolledUp:true 
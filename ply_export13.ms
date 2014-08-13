-- MAXScript utility for exporting one editable mesh to .PLY (Stanford Triangle) format
-- Exports vertices, edges and vertex colors in ASCII and Binary Big-Endian format
--
-- !!!! requires avg_dlx50.dlx (Avguard Extensions) Version 5.0.4 !!!!
-- (c) Martin Breidt
--
-- This code is released under "Quote ware" license:
--      If you use this tool in a production environment with a group of more than two people,
--      or have used it in the past under such conditions, then you are obliged to tell 
--      me (martin@breidt.net) about it and allow me to list that project title and your 
--      company name as a reference on my website http://scripts.breidt.net
--

fn getVCUsingVert theObj theVert = 
-- return vertex color for given vertex of editable mesh; return undefined if error
(
	local f,v,i,a
		
	if not ((classof theObj == Editable_mesh) or 
	(classof theObj == triMesh)) then return undefined 
	
	local cpv_verts = #()

	-- get all faces using that vertex
	a = meshop.getFacesUsingVert theObj theVert

	-- collect all CPVs that are being used by those faces
	for i in a do (
		append cpv_verts (getVCFace theObj i)
		-- cpv_verts is array of Point3
	)

	local found = 0
	-- start with face 1, vertex #1
	f = 1
	v = 1
	
	while found==0 do (
		found = 1
		-- check against all remaining CPVs
		for i = f+1 to cpv_verts.count do (
			-- found=0 if none of the current three CPVs fits
			if (cpv_verts[f][v] != cpv_verts[i][1]) and
			(cpv_verts[f][v] != cpv_verts[i][2]) and
			(cpv_verts[f][v] != cpv_verts[i][3]) then found = 0
		)
		-- increment CPV counter up to 3, then increment face counter
		v += 1
		if (v > 3) then (
			v = 1
			f += 1
			if (f > cpv_verts.count) then (
				print "getVCUsingVert fatal error: Could not find common CPV vertex"
				found = 2
			)
		)
	)
	if found==1 then return (getVertColor theObj (cpv_verts[f][v] as integer)) else return undefined
) -- end getVCUsingVert


fn WriteASCII_PLY fname theObj do_cpv scaleval = (
-- write out ASCII .PLY file fname from theObject, with otional Colors per vertex and scaling
	fs = createFile fname
--	fs = OpenFile fname mode:"w"
	
	format "ply\n" to:fs
	format "format ascii 1.0\n" to:fs
	format "comment Made by ply_export13.ms\n" to:fs
	format "comment Object % exported on %\n" theObj.name localTime to:fs
	
	vertcount = theObj.numverts
	facecount = theObj.numfaces
				
	format "element vertex %\n" vertcount to:fs
	format "property float x\n" to:fs
	format "property float y\n" to:fs
	format "property float z\n" to:fs
	
	if do_cpv then (
		if (theObj.numcpvverts == 0) then (
			messageBox "No vertex colors found! Not exporting vertex colors." title:"PLY Export Error" beep:true
			do_cpv = false
		) else (
			format "property uchar red\n" to:fs
			format "property uchar green\n" to:fs
			format "property uchar blue\n" to:fs
		)
	)
	
	format "element face %\n" facecount to:fs
	format "property list uchar int vertex_index\n" to:fs
	format "end_header\n" to:fs
	
	for i = 1 to vertcount do (
		-- Vertex XYZ
		vp = (in coordsys local (meshOp.getVert theObj i)) * scaleval
		format "% % %" vp.x vp.y vp.z to:fs
		if do_cpv then (
			-- Vertex RGB
			vc = (getVCUsingVert theObj i)
			format " % % %" (vc.r as integer) (vc.g as integer) (vc.b as integer) to:fs 
		)
		format "\n" to:fs
	)
	
	for i = 1 to facecount do (
		-- Face List
		f = getFace theObj i
		format "3 % % %\n" ((f.x-1) as integer) ((f.y-1) as integer) ((f.z-1) as integer) to:fs
	)
	close fs
) -- end WriteASCII_PLY


fn WritePLYString bstream txt =
-- Write out string to binary file, terminate string with 0x0A
(
	if ((classOf bstream)!=BinStream) then (
		format "WritePLYString Error: Not a BinStream\n"
		return undefined
	) 
	WriteString bstream txt
	fseek bstream -1 #seek_cur
	WriteByte bstream 0x0a
	return true
) -- end WritePLYString


fn WritePLYval wstream filename val =
-- Write out float value to binary file
(
	if ((classOf val) == Float) then (
		swap_val = bit.floatAsInt val				-- type-cast to Integer (requires avg_dlx50.dlx v 5.0.4)
		swap_val = bit.swapBytes swap_val 1 4		-- swap Byes No. 1 and 4
		swap_val = bit.swapBytes swap_val 2 3		-- swap Byes No. 2 and 3
		WriteLong wstream swap_val													-- Write out 4-byte Float data with swapped bytes (big-endian)
	) else if ((classOf val) == Integer) then (
		swap_val = bit.swapBytes val 1 4			-- swap Byes No. 1 and 4
		swap_val = bit.swapBytes swap_val 2 3		-- swap Byes No. 2 and 3
		WriteLong wstream swap_val					-- Write out 4-byte Integer data with swapped bytes (big-endian)
	) else (
		print "WritePLYval Error: Float or Integer value expected!"
		return undefined
	)
)

fn WriteBinary_PLY fname theObj do_cpv scaleval = (
-- write out Binary big-endian .PLY file fname from theObject, with otional Colors per vertex and scaling
	bs = fopen fname "wb"
	
	WritePLYString bs "ply"
	WritePLYString bs "format binary_big_endian 1.0"
	WritePLYString bs "comment Made by ply_export.ms" to:fs
	WritePLYString bs ("comment Object "+ theObj.name +" exported on "+ (localTime as string))
	
	vertcount = theObj.numverts
	facecount = theObj.numfaces
				
	WritePLYString bs ("element vertex " + (vertcount as string))
	WritePLYString bs "property float x"
	WritePLYString bs "property float y"
	WritePLYString bs "property float z"
	
	if do_cpv then (
		if (theObj.numcpvverts == 0) then (
			messageBox "No vertex colors found! Not exporting vertex colors." title:"PLY Export Error" beep:true
			do_cpv = false
		) else (
			WritePLYString bs "property uchar red"
			WritePLYString bs "property uchar green"
			WritePLYString bs "property uchar blue"
		)
	)
	
	WritePLYString bs ("element face " + (facecount as string))
	WritePLYString bs "property list uchar int vertex_index"
	WritePLYString bs "end_header"
	
	for i = 1 to vertcount do (
		-- Vertex XYZ
		vp = (in coordsys local (meshOp.getVert theObj i)) 
		
		WritePLYval bs fname (vp.x * scaleval)
		WritePLYval bs fname (vp.y * scaleval)
		WritePLYval bs fname (vp.z * scaleval)
		
		if do_cpv then (
			-- Vertex RGB
			vc = (getVCUsingVert theObj i)
			WriteByte bs vc.r #unsigned
			WriteByte bs vc.g #unsigned
			WriteByte bs vc.b #unsigned
		)
	)
	
	for i = 1 to facecount do (
		-- Face List
		f = getFace theObj i
		WriteByte bs 3								-- Triangles
		WritePLYval bs fname ((f.x-1) as integer)	-- PLY uses zero-based indices
		WritePLYval bs fname ((f.y-1) as integer)
		WritePLYval bs fname ((f.z-1) as integer)
	)
	
	fclose bs
) -- end WriteBinary_PLY



fn pick_flt obj = ((classOf obj == Editable_mesh) or (classOf obj == triMesh))

rollout AboutExportPLYfloater "About..." rolledUp:true
(
	label l1 "PLYExport v1.3 - 10.10.02 M. Breidt"
	label l2
	label l3 "Exports an editable mesh to .PLY"
	label l4 "(Stanford Triangle) format in ASCII"
	label l5 "or big-endian binary"
)

rollout ExportPLYfloater "Export to PLY" 
(
	local obj

	label o1 "Object:" across:3 align:#left
	label o2 "<none>" align:#left
	pickButton pickB "Pick" filter:pick_flt
	group "Options:"
	(
		checkbox vcol_check "Vertex Colors" checked:false across:2
		spinner scale_spin "Scale" range:[0.0001,1000,1.0] width:80 align:#right scale:0.01
		radiobuttons fileType_b "File Type:" labels:#("ASCII","Binary Big-Endian") default:2
	)
	
	button do_export "Export object" enabled:false
	
	on pickB picked o do (
		obj = o
		do_export.enabled = true
		o2.text = o.name
	)

	on do_export pressed do (	
		file_name = getSaveFileName types:"Stanford PLY (*.ply)|*.ply|All (*.*)|*.*|"
		if file_name != undefined then (
			start_t = timestamp()
			if (fileType_b.state == 1) then (
				setWaitCursor()
				format "Creating ASCII file\n"
				WriteASCII_PLY file_name obj vcol_check.state scale_spin.value
				setArrowCursor()
				format "ASCII .PLY exported\n"
			) else if (fileType_b.state == 2) then (
				setWaitCursor()
				format "Creating binary big-endian file\n"
				WriteBinary_PLY file_name obj vcol_check.state scale_spin.value 
				setArrowCursor()
				format "Binary big-endian .PLY exported\n"
			)
			end_t = timestamp()
			format "Export took % seconds\n" ((end_t - start_t)/1000.0)
		) -- end if 
	) -- end on
) -- end rollout

if myPLYFloater != undefined then (
	closeRolloutFloater myPLYFloater
)

myPLYFloater = newRolloutFloater "PLY Export" 218 192
addRollout AboutExportPLYfloater myPLYFloater
addRollout ExportPLYfloater myPLYFloater

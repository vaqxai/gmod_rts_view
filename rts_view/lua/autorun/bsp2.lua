include('includes/modules/sh_statemachine.lua')
include('includes/modules/sh_struct.lua')
include('includes/modules/sh_task.lua')
include('includes/modules/sh_geomutils.lua')
include('includes/modules/sh_rect.lua')
include('includes/modules/sh_irt.lua')

include('includes/modules/sh_poly.lua')
include('includes/modules/sh_brush.lua')
include('includes/modules/sh_bsptypes.lua')
include('includes/modules/sh_bsp2.lua')

if CLIENT then
    local scale = 1

    local MESHES = {}
    local MATERIALS = {}
    local ENTITIES = {}

    local LOADED = false

    function bsp2.GetModelInfo()
        if not LOADED then return nil end

        return {
            meshes = MESHES,
            materials = MATERIALS,
            entities = ENTITIES,
            scale = scale
        }
    end

    local function buildUV(edge, texinfo)
        local s = texinfo.textureVecs.s
        local t = texinfo.textureVecs.t

        local u = (s.w + s.x * edge.x + s.y * edge.y + s.z * edge.z) / texinfo.texdata.width
        local v = (t.w + t.x * edge.x + t.y * edge.y + t.z * edge.z) / texinfo.texdata.height

        return u, v
    end

    local function buildTri(buffer, vertex, u, v)
        buffer[#buffer + 1] = {
            pos = vertex * scale,
            u = u,
            v = v,
        }

        local tris =  {}

        if #buffer == 3 then
            for i = 1, 3 do
                tris[#tris + 1] = buffer[i]
            end

            table.remove(buffer, 2)
        end

        return tris
    end

    hook.Add('CurrentBSPReady', 'bsp2.CurrentBSPReady', function()
        local bsp = bsp2.GetCurrent()

        local meshes = {}
        local materials = {}
        local entities = {}

        local faces = bsp[LUMP_FACES] -- Lump 7
        local texinfo = bsp[LUMP_TEXINFO] -- Lump 6
        local surfedges = bsp[LUMP_SURFEDGES] -- Lump 13

        -- Map every material to a set of faces which reference the material
        local mats = {}
        for _, face in ipairs(faces) do
            local data = texinfo[face.texinfo.id]
            local name = data.texdata.material

            -- Ignore skybox materials
            if name:sub(1, 6):lower() == 'tools/' then continue end

            mats[data] = mats[data] or {}

            table.insert(mats[data], face)
        end

        -- Using this map, create a new material and build a mesh from every face
        for data, material in pairs(mats) do
            local triangles = {}

            -- Create a new material

            local info = texinfo[material[1].texinfo.id]

            local msh = Mesh()
            local mat = CreateMaterial(tostring(info) .. '_texinfo', 'UnlitGeneric', {
                ['$basetexture'] = Material(info.texdata.material):GetTexture('$basetexture'):GetName(),
                ['$detailscale'] = 1,
                ['$reflectivity'] = util.StringToType(info.texdata.reflectivity, 'Vector'),
                ['$model'] = 1
            })

            table.insert(meshes, msh)
            table.insert(materials, mat)

            -- Construct a mesh from all the faces

            for _, face in ipairs(material) do
                local buffer = {}

                for i = 1, face.numedges do
                    local surfedge = surfedges[face.firstedge + i]

                    local vertex1 = util.StringToType(surfedge[1], 'Vector')
                    local vertex2 = util.StringToType(surfedge[2], 'Vector')

                    local u1, v1 = buildUV(vertex1, data)

                    table.Add(triangles, buildTri(buffer, vertex1, u1, v1))

                    local u2, v2 = buildUV(vertex2, data)

                    table.Add(triangles, buildTri(buffer, vertex2, u2, v2))
                end
            end

            msh:BuildFromTriangles(triangles)
        end

        for k, v in ipairs(bsp.entities) do
            if not (v.model and v.origin and v.angles) then continue end

            local e = ClientsideModel(v.model)
            e:SetNoDraw(true)
            e:SetRenderOrigin(util.StringToType(v.origin, 'Vector') * scale)
            e:SetRenderAngles(util.StringToType(v.angles, 'Angle'))
            e:SetModelScale(scale, 0)
            e:SetSkin(tonumber(v.skin or 0) or 0)
            e:Spawn()

            table.insert(entities, e)
        end

        LOADED = true
		print("Oi, fucker, the map thingy has finished loading, means you can proceed.")

        MESHES = meshes
        MATERIALS = materials
        ENTITIES = entities
    end)
end

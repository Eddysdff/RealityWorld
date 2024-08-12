--#region Model

RealityInfo = {
  Dimensions = 2,
  Name = 'ExampleReality',
  ['Render-With'] = '2D-Tile-0',
}

RealityParameters = {
  ['2D-Tile-0'] = {
    Version = 0,
    Spawn = { 5, 7 },
    -- This is a tileset themed to Llama Land main island
    Tileset = {
      Type = 'Fixed',
      Format = 'PNG',
      TxId = 'h5Bo-Th9DWeYytRK156RctbPceREK53eFzwTiKi0pnE', -- TxId of the tileset in PNG format
    },
    -- This is a tilemap of sample small island
    Tilemap = {
      Type = 'Fixed',
      Format = 'TMJ',
      TxId = 'koH7Xcao-lLr1aXKX4mrcovf37OWPlHW76rPQEwCMMA', -- TxId of the tilemap in TMJ format
      -- Since we are already setting the spawn in the middle, we don't need this
      -- Offset = { -10, -10 },
    },
  },
  ['Audio-0'] = {
    Bgm = {
      Type = 'Fixed',
      Format = 'WEBM',
      TxId = 'k-p6enw-P81m-cwikH3HXFtYB762tnx2aiSSrW137d8',
    }
  },
}

RealityEntitiesStatic = {
  ['HuxQqo8G9RFA5zq4ANAMpQvAXPl7MIRwkiBf_aVT0C0'] = {  -- Travel Advisor ProcessId
    Position = { 6, 10 },  -- Travel Advisor position
    Type = 'Avatar',
    Metadata = {
      DisplayName = 'Llama travel advice',
      SkinNumber = 3, 
      Interaction = {
        Type = 'SchemaExternalForm',
        Id = 'GetTravelAdvice'  -- type
      },
    },
  },
}


--#endregion

return print("Loaded Reality Template")

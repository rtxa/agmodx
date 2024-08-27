--- 
hide_table_of_contents: true
---

# FAQ

## Technical FAQ

<details>
  <summary>Why my server isn't showing up in the server browser list on pause?</summary>

  If you are using Reunion, this is related to a bug with `EnableQuerylimiter`. You can fix this by downloading the latest version or by setting `EnableQueryLimiter = 0` in `reunion.cfg`.
</details>

<details>
  <summary>Why game mode names are not being updated on the server browser?</summary>

  This issue happens because latest HLDS now requires to hook `IServerGameDLL::GetGameDescription` from SteamWorks API (with SteamTools) to make it work again. Using DProto or ReHLDS fixes the issue.
</details>

<details>
  <summary>Why my server password is not being removed on map change?</summary>

  Newer HL builds have made executing `server.cfg` on map change optional with the CVar `mapchangecfgfile`. Add in `startup_server.cfg` or `server.cfg` this line `mapchangecfgfile server.cfg` and it should work again.
</details>

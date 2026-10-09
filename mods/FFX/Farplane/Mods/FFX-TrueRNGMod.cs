//css_reference "..\bin\Debug\farplane.exe";
using System;
using System.Linq;
using System.Windows;

using Farplane;
using Farplane.Common;
using Farplane.FarplaneMod;
using Farplane.FFX;
using Farplane.FFX.Data;
using Farplane.FFX.Values;

public class FFXTrueRNGMod : IFarplaneMod
{
    private bool _modActive = false;
    private static int _offsetTrueRNG = 0x3988F3;

    byte[] _ModTrueRNG = new byte[]
    {
        0x31, 0xD2, 0x90
    };

    public string Name
    {
        get { return "True RNG Mod"; }
    }

    public string Author
    {
        get { return "Dragonloverlord"; }
    }

    public string Description
    {
        get { return "Restores the original RNG of FFX. !!!Experimental Use At Own RISK!!!"; }
    }

    public GameType GameType
    {
        get { return GameType.FFX; }
    }

    public bool Activated
    {
        get { return _modActive; }
    }
	
    public void Activate()
    {
        if (_modActive) return;
        ModLogger.WriteLine("Activating True RNG Mod");

        // No check (yet)
        Memory.WriteBytes(_offsetTrueRNG, _ModTrueRNG);

        _modActive = true;
    }

    public void Deactivate()
    {
        if (!_modActive) return;
        ModLogger.WriteLine("Deactivating True RNG Mod");
        ModLogger.WriteLine("Deactivation NYI");
        _modActive = false;
    }

    public static void ValidateBytes(byte[] bytes)
    {
        // Verify bytes against original bytes here
    }

    public void Update()
    {
        return;
    }
}
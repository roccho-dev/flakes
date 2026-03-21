{ lib }:

{
  mkOneshotService =
    { description
    , script
    , workingDirectory ? null
    }:
    {
      Unit.Description = description;
      Service = {
        Type = "oneshot";
        ExecStart = script;
      } // lib.optionalAttrs (workingDirectory != null) {
        WorkingDirectory = workingDirectory;
      };
    };

  mkTimer =
    { description
    , onCalendar
    , persistent ? true
    , randomizedDelaySec ? "30m"
    , accuracySec ? "15m"
    }:
    {
      Unit.Description = description;
      Timer = {
        OnCalendar = onCalendar;
        Persistent = persistent;
        RandomizedDelaySec = randomizedDelaySec;
        AccuracySec = accuracySec;
      };
      Install.WantedBy = [ "timers.target" ];
    };
}

# Container identifier
:local hostname "mikrotik-west-1";

/container 
:local id [find where hostname=$hostname];
:local rootdir [get $id root-dir];
:local dns [get $id dns];
:local logging [get $id logging];
:local status [get $id status];
:local mounts [get $id mounts];
:local envlist [get $id envlist];
:local interface [get $id interface];
:local startonboot [get $id start-on-boot];
:global LogPrefix "Tailscale";

:local logI do={
    :global LogPrefix;
    :put ($LogPrefix . ": " . $1);
    :log info ($LogPrefix . ": " . $1);
}

# Stop the container
$logI "Stopping the container...";
stop $id
:while ($status != "stopped") do={
    $logI "Waiting for the container to stop...";
    :delay 5;
    :set status [get $id status];
} 
$logI "Stopped.";

# Remove the container
remove $id
$logI "Removing the container...";
:while ($status = "stopped") do={
    $logI "Waiting for the container to be removed...";
    :delay 5;
    :set status [get $id status];
} 
$logI "Removed.";

# Add the container
:delay 5;
$logI "Adding the container...";
add remote-image=fluent-networks/tailscale-mikrotik:latest \
    interface=$interface envlist=$envlist root-dir=$rootdir mounts=$mounts\
    start-on-boot=$startonboot hostname=$hostname dns=$dns logging=$logging
:do {
    :set status [get [find where hostname=$hostname] status];
    :if ($status != "stopped") do={
        $logI "Waiting for the container to be added...";
        :delay 5;
    }
} while ($status != "stopped")
$logI "Added."

# Start the container
$logI "Starting the container.";
:set id [find where hostname=$hostname];
start $id

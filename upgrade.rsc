# Container identifier
:global hostname "mikrotik-west-1";

/container 
:global id [find where hostname=$hostname];
:global rootdir [get $id root-dir];
:global dns [get $id dns];
:global logging [get $id logging];
:global status [get $id status];

# Stop the container
stop $id
:put "Stopping the container...";
:while ($status != "stopped") do={
    :put "Waiting for the container to stop...";
    :delay 5;
    :set status [get $id status];
} 
:put "Stopped.";

# Remove the container
remove $id
:put "Removing the container...";
:while ($status = "stopped") do={
    :put "Waiting for the container to be removed...";
    :delay 5;
    :set status [get $id status];
} 
:put "Removed.";

# Add the container
:delay 5;
:put "Adding the container...";
add remote-image=fluent-networks/tailscale-mikrotik:latest \
    interface=veth1 envlist=tailscale root-dir=$rootdir \
    start-on-boot=yes hostname=$hostname dns=$dns logging=$logging
:do {
    :set status [get [find where hostname=$hostname] status];
    :if ($status != "stopped") do={
        :put "Waiting for the container to be added...";
        :delay 5;
    }
} while ($status != "stopped")
:put "Added."

# Start the container
:put "Starting the container.";
:set id [find where hostname=$hostname];
start $id

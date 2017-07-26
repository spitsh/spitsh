#| Service is an experimental class to interface with the operating
#| system's built in service manager.
class Service is List[Pair] {
    method start    {
        info "starting $self<name>";
        if $self<start> {
            ${eval $_};
        }
        else {
            ${service $self<name> start};
        }
    }
    method stop     {
        info "stopping $self<name>";
        if $self<stop> {
            ${eval $_};
        }
        else {
            ${service $self<name> stop };
        }
    }
    method restart  {
        info "Restarting $self<name>";
        if $self<restart> {
            ${eval $_};
        }
        else {
            ${service $self<name> restart};
        }
    }
    method running? {
        if $self<running> {
            ${eval $_};
        }
        else {
            ${service $self<name> status *>X}
        }
    }

    method Bool { $self.running }
}

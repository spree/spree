## Spree 2.0.7 (unreleased) ##

*   Converting timestamps to json now give us miliseconds precision (by monkey
    patching ActiveSupport::TimeWithZone#as_json)
    
    Washington Luiz

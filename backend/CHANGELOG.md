## Spree 2.0.1 (unreleased) ##

*   Symbolize attachment style keys on ImageSettingController otherwise users
    would get *undefined method `processors' for "48x48>":String>* since
    paperclip can't handle key strings.

    *Washington Luiz*

* Fix bug where taxonomy URL was incorrect when Spree was mounted at a non-root path 50ac165c13f6d9123db704b72e9feae86971af70.

    *Washington Luiz*

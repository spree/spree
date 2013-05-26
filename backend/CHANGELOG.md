## Spree 2.1.0 (unreleased) ##

*   Symbolize attachment style keys on ImageSettingController otherwise users
    would get *undefined method `processors' for "48x48>":String>* since
    paperclip can't handle key strings.

    *Washington Luiz*

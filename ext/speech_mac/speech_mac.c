#include <ruby.h>
#include "speech_mac.h"

static VALUE rb_speech_mac_transcribe(VALUE self, VALUE path) {
    const char *c_path = StringValueCStr(path);
    char *result = speech_mac_transcribe(c_path);
    if (result == NULL) {
        return rb_utf8_str_new_cstr("");
    }
    VALUE rb_result = rb_utf8_str_new_cstr(result);
    speech_mac_free(result);
    return rb_result;
}

void Init_speech_mac(void) {
    VALUE module = rb_define_module("SpeechMac");
    rb_define_singleton_method(module, "transcribe", rb_speech_mac_transcribe, 1);
}

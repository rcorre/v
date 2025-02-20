module main

import os
import testing
import v.util
import arrays

const (
	vet_known_failing_exceptions    = []string{}
	vet_folders                     = [
		'vlib/sqlite',
		'vlib/v',
		'vlib/x/json2',
		'vlib/x/ttf',
		'cmd/v',
		'cmd/tools',
		'examples/2048',
		'examples/tetris',
		'examples/term.ui',
	]
	verify_known_failing_exceptions = [
		// Handcrafted meaningful formatting of code parts (mostly arrays)
		'examples/sokol/02_cubes_glsl/cube_glsl.v',
		'examples/sokol/03_march_tracing_glsl/rt_glsl.v',
		'examples/sokol/04_multi_shader_glsl/rt_glsl.v',
		'examples/sokol/05_instancing_glsl/rt_glsl.v',
		'vlib/gg/m4/graphic.v',
		'vlib/gg/m4/m4_test.v',
		'vlib/gg/m4/matrix.v',
		'vlib/builtin/int_test.v' /* special number formatting that should be tested */,
		// TODOs and unfixed vfmt bugs
		'vlib/builtin/int.v' /* TODO byteptr: vfmt converts `pub fn (nn byteptr) str() string {` to `nn &byte` and that conflicts with `nn byte` */,
		'vlib/builtin/string_charptr_byteptr_helpers.v' /* TODO byteptr: a temporary shim to ease the byteptr=>&byte transition */,
		'vlib/v/tests/fn_high_test.v', /* param name removed */
		'vlib/v/tests/generics_return_generics_struct_test.v', /* generic fn param removed */
		'vlib/v/tests/interop_test.v', /* bad comment formatting */
		'vlib/v/tests/string_interpolation_test.v' /* TODO byteptr: &byte.str() behaves differently than byteptr.str() */,
		'vlib/v/gen/js/tests/js.v', /* local `hello` fn, gets replaced with module `hello` aliased as `hl` */
		'examples/c_interop_wkhtmltopdf.v' /* &charptr --> &&char */,
	]
	vfmt_verify_list                = [
		'cmd/',
		'examples/',
		'tutorials/',
		'vlib/',
	]
	vfmt_known_failing_exceptions   = arrays.merge(verify_known_failing_exceptions, [
		'vlib/strconv/' /* prevent conflicts, till the new pure V string interpolation is merged */,
		'vlib/net/' /* prevent conflicts, till ipv6 support is merged */,
		'vlib/term/ui/input.v' /* comment after a struct embed is removed */,
		'vlib/regex/regex_test.v' /* contains meaningfull formatting of the test case data */,
		'vlib/readline/readline_test.v' /* vfmt eats `{ Readline }` from `import readline { Readline }` */,
		'vlib/glm/glm.v' /* `mut res &f32` => `mut res f32`, which then fails to compile */,
		'vlib/fontstash/fontstash_structs.v' /* eats fn arg names for inline callback types in struct field declarations */,
		'vlib/crypto/sha512/sha512block_generic.v' /* formatting of large constant arrays wraps to too many lines */,
		'vlib/crypto/aes/const.v' /* formatting of large constant arrays wraps to too many lines */,
	])
)

const (
	vexe   = os.getenv('VEXE')
	vroot  = os.dir(vexe)
	is_fix = '-fix' in os.args
)

fn main() {
	args_string := os.args[1..].join(' ')
	pass_args := args_string.all_before('test-cleancode')
	v_test_vetting(pass_args)
}

fn tsession(vargs string, tool_source string, tool_cmd string, tool_args string, flist []string, slist []string) testing.TestSession {
	os.chdir(vroot)
	title_message := 'running $tool_cmd over most .v files'
	testing.eheader(title_message)
	mut test_session := testing.new_test_session('$vargs $tool_args', false)
	test_session.files << flist
	test_session.skip_files << slist
	util.prepare_tool_when_needed(tool_source)
	// note that util.prepare_tool_when_needed will put its temporary files
	// in the VTMP from the test session too, so they will be cleaned up
	// at the end
	test_session.test()
	eprintln(test_session.benchmark.total_message(title_message))
	return test_session
}

fn v_test_vetting(vargs string) {
	expanded_vet_list := util.find_all_v_files(vet_folders) or { return }
	vet_session := tsession(vargs, 'vvet', 'v vet', 'vet', expanded_vet_list, vet_known_failing_exceptions)
	//
	fmt_cmd, fmt_args := if is_fix { 'v fmt -w', 'fmt -w' } else { 'v fmt -verify', 'fmt -verify' }
	vfmt_list := util.find_all_v_files(vfmt_verify_list) or { return }
	exceptions := util.find_all_v_files(vfmt_known_failing_exceptions) or { return }
	verify_session := tsession(vargs, 'vfmt.v', fmt_cmd, fmt_args, vfmt_list, exceptions)
	//
	if vet_session.benchmark.nfail > 0 || verify_session.benchmark.nfail > 0 {
		eprintln('\n')
		if vet_session.benchmark.nfail > 0 {
			eprintln('WARNING: `v vet` failed $vet_session.benchmark.nfail times.')
		}
		if verify_session.benchmark.nfail > 0 {
			eprintln('WARNING: `v fmt -verify` failed $verify_session.benchmark.nfail times.')
		}
		exit(1)
	}
}

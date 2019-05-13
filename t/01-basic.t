=pod

=encoding utf8

=head1 SUMMARY

Unit Test for Parse::ARGV
since 2019/05/10 by H.Seo

=head1 USAGE

case1:

```
$ fswatch -r ./lib ./t | while read f ;do clear ;date ;prove -lv t/01-basic.t ;done
```


=cut

use strict;
use warnings;

use Test::More;
# use Test::Exception;

use Scalar::Util qw/blessed/;

# use Data::Dumper;
# $Data::Dumper::Terse	= 1;
# $Data::Dumper::Sortkeys	= 1;
# $Data::Dumper::Indent	= 2;

{
	BEGIN
	{
		BAIL_OUT("use Parse::ARGV faild.") unless use_ok('Parse::ARGV');
	}
	
	my $pa = Parse::ARGV->new(
		[
			'--bool-flag',
			'--string-required' => 'some string',
			'--handle-code'	=> 'hoge@example.com',
			'--with-alias'	=> 'alias is W',
			qw/aaa bbb ccc/
		],
		{
			'bool-flag'	=>
			{
				handle	=> 'bool'
			},
			'string-required'	=>
			{
				handle	=> 'shift'
			},
			'bool-default-is-false'	=> {},
			'bool-default-set-true'	=>
			{
				default	=> 1
			},
			'handle-code'	=>
			{
				handle	=> sub
				{
					my ( $self ,$context_argv ) = @_;

					my $value = shift @$context_argv;

					return quotemeta $value;
				}
			},
			'with-alias'	=>
			{
				handle	=> 'shift',
				alias	=> 'W',
			}
		}
	);

	# constructor
	ok( blessed $pa
		,'Construct Parse::ARGV OK.'
	);

	# bool type
	ok( 1 && $pa->bool_flag
		,'bool-flag accepted.'
	);

	# argument required option
	is( $pa->string_required
		,'some string'
		,'string-required is "some string".'
	);

	# bool type & default is false when no given option.
	ok( ! $pa->bool_default_is_false
		,'bool-default is FALSE.'
	);

	# bool type & default is true when no given option.
	ok( 1 && $pa->bool_default_set_true
		,'bool-default-set-true is true.'
	);

	# Use custom code at parse
	is( $pa->handle_code
		,'hoge\@example\.com'
		,'handle_code is "hoge\@example\.com"'
	);

	# Alias
	is( $pa->W
		,'alias is W'
		,'W is "alias is W"'
	);

	is( $pa->W
		,$pa->with_alias
		,'$pa->W is $pa->with_alias'
	);

	# Other single argv
	is( $pa->single_argv(0)
		,'aaa'
		,'First argv "aaa", that separate from --/- option.'
	);

	is_deeply(
		[$pa->single_argv]
		,[qw/aaa bbb ccc/]
		,'$pa->single_argv deeply ok in array context.'
	);


	done_testing();
}

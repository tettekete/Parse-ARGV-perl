package Parse::ARGV;

use 5.006;
use strict;
use warnings;

{
	our $VERSION = '0.0001';
}

use overload (
	# q[""] => 'stringify'
	'bool' => '_parse_ok'
	,fallback => 1
);

sub new
{
	my $class	= shift @_;

	my $argv_src	= undef;
	my $config		= undef;

	# コールシンタックスにより引数割り当て調整をします
	if( ref $_[0] eq 'ARRAY' )
	{
		( $argv_src , $config ) = @_;
	}
	else
	{
		$argv_src	= [@ARGV];
		$config		= shift @_;
	}

	# config に関する初期化処理
	while(my ($k,$v) = each %$config )
	{
		# handle 指定が無い場合、デフォルトを 'bool' にします。
		$v->{handle} = 'bool' if(! exists $v->{handle} );
	}

	my $self	=
	{
		_config			=> $config,
		_values			=> {},
		_single_argv	=> [],
		_private		=>
		{
			parse_ok	=> undef
		},
	};

	bless $self,ref $class || $class;

	if( $self->_parse( $argv_src ) )
	{
		my $get_safe_name = sub
		{
			my $name = $_[0];

			$name =~ s/-/_/g;
			$name =~ s/^\d+//g;
			$name =~ s/\W//g;

			return $name;
		};

		# アクセサの動的定義
		no strict 'refs';
		{
			for my $k ( keys %{$self->{_config}} )
			{
				my $v		= undef;
				my $alias	= _key_path_fetcher( $self->{_config}
										,$k , 'alias'
							);
				
				if( exists $self->{_values}->{$k})
				{
					$v	= $self->{_values}->{$k};
				}
				elsif( exists $self->{_config}->{$k}->{default} )
				{
					$v	= $self->{_config}->{$k}->{default};
				}

				my $method_name = $get_safe_name->( $k );

				*{__PACKAGE__."::$method_name"} = sub
				{
					return $v;
				};

				if( $alias )
				{
					*{__PACKAGE__."::$alias"} = *{__PACKAGE__."::$method_name"};
				}
			}
		}
	}

	return $self;
}

sub _parse
{
	my $self		= shift @_;
	my $argv_src	= shift @_;

	my @argv	= @$argv_src;
	my $config	= shift @_;	# POD を参照
	
	my @allowOpts = keys %$config;

	map{ push @allowOpts , $config->{$_}->{alias} }
		grep {exists $config->{$_}->{alias} } keys %$config;

	while( @argv )
	{
		my $in	= shift @argv;
		my $opt	= undef;

		if( $in =~ /^-([^\-].*)/ )
		{
			# ショートオプション系
			$opt = $1;
		}
		elsif( $in =~ /^--(.+)/ )
		{
			# ロングオプション系
			$opt = $1;
		}
		else
		{
			# 通常の引数
			push @{$self->{'_single_argv'}} ,$in;
			next;
		}

		if( ! defined $opt || ( @allowOpts && ! grep { $opt eq $_} @allowOpts ))
		{
			$self->_set_parse_error
			(
				"Unknown option '$in'\nAvailable options are : \n"
				.join
				(
					',',
					map{$_ = length $_ == 1 ? "-$_" : "--$_" } @allowOpts
				)
			);

			return;

		}
			

		if( $opt )
		{
			my $handle	= _key_path_fetcher( $self->{_config}
											,$opt , 'handle'
										);
			# my $alias	= _key_path_fetcher( $self->{_config}
			# 								,$opt , 'alias'
			# 							);

			if( $handle eq 'bool' )
			{
				$self->{_values}->{$opt}		= 1;
				# $self->{_values}->{$alias} 		= 1 if( $alias );
			}
			elsif( $handle eq 'shift' )
			{
				$self->{_values}->{$opt}		= shift @argv;
				# $self->{_values}->{$alias}		= $self->{_values}->{$opt} if( $alias )
			}
			elsif( 'CODE' eq ref $handle )
			{
				$self->{_values}->{$opt}		= $handle->( $self ,\@argv );
				# $self->{_values}->{$alias}		= $self->{_values}->{$opt};
			}
			else
			{
				warn "Unknown handler for '$opt'"
			}
		}
	}

	return $self->_parse_ok(1);
}

sub _key_path_fetcher
{
	my $obj = shift @_;
	my @keyPath	= @_;

	while( @keyPath )
	{
		my $key = shift @keyPath;
		
		if( 'ARRAY' eq ref $obj
		 && $key =~ /^-{0,1}\d+$/)
		{
			$obj = $obj->[$key];
		}
		elsif( 'HASH' eq ref $obj )
		{
			$obj = $obj->{$key}
		}
		else
		{
			return undef;
		}
	}

	return $obj;
}

sub _private_accessor
{
	my $self	= shift @_;
	my $name	= shift @_;

	if( 1 == @_ )
	{
		return $self->{_private}->{$name} = $_[0];
	}
	else
	{
		return $self->{_private}->{$name};
	}
}

sub _set_parse_error
{
	my $self = shift @_;

	return $self->_private_accessor(
			'parse_error'
			,@_
		);
}

sub _parse_ok
{
	my $self = shift @_;

	return $self->_private_accessor(
			'parse_ok'
			,@_
		);
}

=head3 single_argv( [$idx] )

=cut


sub single_argv
{
	my $self	= shift @_;
	my $idx		= shift @_;

	return $self->{_single_argv}->[$idx] if( defined $idx && $idx =~ /^-?\d+$/ );	# 整数値が指定されていた場合
	return @{$self->{_single_argv}}
}

1;

__END__

=head1 NAME

Parse::ARGV - The great new Parse::ARGV!

=head1 VERSION

Version 0.0001

=cut


=head1 SYNOPSIS

Quick summary of what the module does.

Provides @ARGV parser for perl scripts acting as CLI tool.

    use Parse::ARGV;

    my $argv = Parse::ARGV->new(
        'version'    => {}, # handle as bool by default.
        'verbose'    =>
        {
            alias    => 'V'
        },
        ,'name'      =>
        {
            handle    => 'shift',
        },
        'email'    => sub
        {
            my ( $self ,$context_argv ) = @_;

            my $value = shift @$context_argv;

            return quotemeta $value;
        }
    )

=head1 Motivation

vs `Getopt::Long` :

- 受け付けるオプションの定義的宣言
    - 必要な場面で `GetOptions` するコードになると、結局の所どんな引数に対応しているのか？参照箇所は？となってしまう
- オプションの数だけ変数を用意する必要が無い
    - インスタンスを一つ格納できれば良い
- 独自 DSL を極力排除
    - `GetOptions('verbose!' => \$verbose)` これを初見でデフォルト値が FALSE のフラグ型、と分かるだろうか。入力値の NOT が入ると読めてしまうのでは無いか

=head1 TODO

- CGI->param 的なオリジナルのオプション名を使ったアクセサの実装
- 同一オプションの複数入力を配列に格納する
- Moo の `isa` ライクなバリデータ向けコールバックの実装
- shared_instance 実装 << 必要性があれば

=head1 METHODS

=head2 Public

=head3 new([\@ARGV ,] \%config )


=head3 single_argv( [$idx] )

=head2 Accessor (auto grown)

パースされたオプション名は、以下の変換を行った名前を使って取得することが出来ます。

    $name =~ s/-/_/g;
    $name =~ s/^\d+//g;
    $name =~ s/\W//g;

要は変数として使えるように変換した名前です。

例:

    --foo-bar → $argv->foo_bar
    -V        → $argv->V


=head1 AUTHOR

H.Seo, C<< <tettekete at example.com> >>

=head1 BUGS


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2019 H.Seo.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Parse::ARGV

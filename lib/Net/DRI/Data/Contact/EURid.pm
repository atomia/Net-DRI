## Domain Registry Interface, Handling of contact data for EURid
##
## Copyright (c) 2005,2006,2007,2008,2009 Patrick Mevzek <netdri@dotandco.com>. All rights reserved.
##
## This file is part of Net::DRI
##
## Net::DRI is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## See the LICENSE file that comes with this distribution for more details.
#
# 
#
#########################################################################################

package Net::DRI::Data::Contact::EURid;

use strict;
use warnings;

use base qw/Net::DRI::Data::Contact/;

use Net::DRI::DRD::EURid;
use Net::DRI::Exception;
use Net::DRI::Util;

our $VERSION=do { my @r=(q$Revision: 1.10 $=~/\d+/g); sprintf("%d".".%02d" x $#r, @r); };

__PACKAGE__->register_attributes(qw(type vat lang onhold monitoring_status natural_person country_of_citizenship));

=pod

=head1 NAME

Net::DRI::Data::Contact::EURid - Handle EURid contact data for Net::DRI

=head1 DESCRIPTION

This subclass of Net::DRI::Data::Contact adds accessors and validation for
EURid specific data.

=head1 METHODS

The following accessors/mutators can be called in chain, as they all return the object itself.

=head2 type() 

type of contact : billing, tech, registrant or onsite (mandatory)

=head2 vat()

vat number of contact

=head2 lang()

language of contact, must be in Europe (mandatory)

=head2 onhold()

returned by registry during a contact:info operation

=head2 monitoring_status()

returned by registry during a contact:info operation

=head2 natural_person()

check if person vs organization - true/false (mandatory)

=head2 country_of_citizenship()

created in order to implement the new eligibility criteria for EU citizenship (optional).

country_of_citizenship is mandatory if: 1) <contact-ext:naturalPerson> is set to true; 2) registrant's place of residence is
not located in one of the EAA/EU countries or in one of the EU territories

=head1 SUPPORT

For now, support questions should be sent to:

E<lt>netdri@dotandco.comE<gt>

Please also see the SUPPORT file in the distribution.

=head1 SEE ALSO

http://www.dotandco.com/services/software/Net-DRI/

=head1 AUTHOR

Patrick Mevzek, E<lt>netdri@dotandco.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2005,2006,2007,2008,2009 Patrick Mevzek <netdri@dotandco.com>.
All rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

See the LICENSE file that comes with this distribution for more details.

=cut

####################################################################################################

sub validate
{
 my ($self,$change)=@_;
 $change||=0;
 my @errs;

 $self->SUPER::validate($change); ## will trigger an Exception if problem

 if (!$change)
 {
   Net::DRI::Exception::usererr_insufficient_parameters('Invalid contact information: voice/type/lang/natural_person mandatory') unless ($self->voice() && $self->type()
    && $self->lang() && $self->natural_person());
 }

 ## Lower limits than in EPP (other checks already done in superclass)
 push @errs,'name' if ($self->name() && grep { length($_) > 50 }  ($self->name()));
 push @errs,'org'  if ($self->org()  && grep { length($_) > 100 } ($self->org()));


 push @errs,'type' if ($self->type() && $self->type()!~m/^(?:billing|tech|registrant|onsite)$/);
 push @errs,'vat'  if ($self->vat()  && !Net::DRI::Util::xml_is_token($self->vat(),1,20));
 push @errs,'lang' if ($self->lang() && !exists($Net::DRI::DRD::EURid::LANGA2_EU{lc($self->lang())}));
 push @errs,'natural_person need to be a boolean' if ($self->natural_person() && !Net::DRI::Util::xml_is_boolean($self->natural_person()));

 Net::DRI::Exception::usererr_invalid_parameters('Invalid contact information: '.join('/',@errs)) if @errs;

 ## if eurid:type is billing or tech, contact:org is mandatory
 Net::DRI::Exception::usererr_insufficient_parameters('Org is mandatory for billing or tech contacts') if ($self->type() && $self->type()=~m/^(?:type|billing)$/ && !$self->org());

 Net::DRI::Exception::usererr_insufficient_parameters('Fax is mandatory for billing contacts') if (defined($self->type()) && ($self->type() eq 'billing') && !$self->fax());

 ## For registrants, country must be in EU (for ORGs). Individuals are able to order domains if countryOfCitizenship part of EEA
 Net::DRI::Exception::usererr_invalid_parameters('Registrant contact must be in EU (if is a organization)') if ($self->type() && ($self->type() eq 'registrant') && 
 !exists($Net::DRI::DRD::EURid::CCA2_EU{uc($self->cc())}) && $self->natural_person() eq 'false');

# country_of_citizenship is mandatory if natural_person is true
 Net::DRI::Exception::usererr_insufficient_parameters('countryOfCitizenship is mandatory if naturalPerson is true') if (defined($self->natural_person()) 
 && $self->natural_person() eq 'true' && self->can("type") && self->type() eq "registrant"  && !$self->country_of_citizenship());

 return 1; ## everything ok.
}

sub init
{
 my ($self,$what,$ndr)=@_;
 if ($what eq 'create')
 {
  my $a=$self->auth();
  $self->auth({pw=>''}) unless ($a && (ref($a) eq 'HASH') && exists($a->{pw}));
  $self->srid('ABCD') unless defined $self->srid(); ## we can not choose the ID
 }
}

####################################################################################################
1;

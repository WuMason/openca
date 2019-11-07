#!/usr/bin/perl

#---------------------------------------------------------------------
# Import the necessary modules
#---------------------------------------------------------------------
use WebService::CaptchasDotNet;
use CGI;

#---------------------------------------------------------------------
# Construct the captchas object. Use same Settings as in query.cgi, 
# height and width aren't necessairy
#---------------------------------------------------------------------
my $captchas = WebService::CaptchasDotNet->new(
                                 client   => 'demo',
                                 secret   => 'secret'#,
                                 #alphabet => 'abcdefghkmnopqrstuvwxyz',
                                 #letters => 6
                                 );

#---------------------------------------------------------------------
# Validate and verify captcha password
#---------------------------------------------------------------------
sub get_body {
    # Read the form values.
    my $query = new CGI;
    my $message  = $query->param ('message');
    my $password = $query->param ('password');
    my $random   = $query->param ('random');

    # Return an error message, when reading the form values fails.
    if (not (defined ($message) and 
             defined ($password) and 
             defined ($random)))
    {
      return 'Invalid arguments.';
    }

    # Check the random string to be valid and return an error message
    # otherwise.
    if (not $captchas->validate ($random))
    {
      return 'Every CAPTCHA can only be used once. The current '
           . 'CAPTCHA has already been used. Try again.';
    }

    # Check that the right CAPTCHA password has been entered and
    # return an error message otherwise.
    # Attention: Only call verify if validate is true
    if (not $captchas->verify ($password))
    {
      return 'You entered the wrong password. '
           . 'Please use back button and reload.';
    }

    # Return a success message.
    return 'Your message was verified to be entered by a human ' .
           'and is "' . $message. '"';
}

#---------------------------------------------------------------------
# Print html page
#---------------------------------------------------------------------
print "Content-Type: text/html\n\n";
print '
<html>
  <head>
    <title>Sample Perl CAPTCHA Query</title>
  </head>
  <h1>Sample Perl CAPTCHA Query</h1>' .
    get_body () . '
</html>';
#---------------------------------------------------------------------
# End
#---------------------------------------------------------------------

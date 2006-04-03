use inc::Module::Install;

name		('Module-Install-Substitute');
abstract	('substitute values into files before install');
version_from	('lib/Module/Install/Substitute.pm');
author		('Ruslan U. Zakirov <Ruslan.Zakirov@gmail.com>');
license		('perl');

requires('File::Spec');
requires('File::Temp');
requires('Cwd');

build_requires('Test::More');
build_requires('Test::File::Contents');

WriteAll();

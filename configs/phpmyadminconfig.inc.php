<?php
declare(strict_types=1);

$cfg['blowfish_secret'] = '<blowfish_secret>';

$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
$cfg['TempDir'] = '/var/www/phpmyadmin/tmp/';

//Recaptcha settings if you want
//$cfg['CaptchaMethod'] = 'invisible'; //checkbox or invisible
//$cfg['CaptchaLoginPublicKey'] = '';
//$cfg['CaptchaLoginPrivateKey'] = '';

$cfg['DefaultLang'] = 'hu';
$cfg['ThemeDefault'] = 'boodark';

$cfg['MysqlSslWarningSafeHosts'] = ['127.0.0.1', 'localhost', 'mariadb.local', '172.17.0.1', '0.0.0.0'];

$i = 0;
$hosts = [
    'localhost',
];

foreach ($hosts as $host) {
    $i++;
    $cfg['Servers'][$i]['host'] = $host;
    $cfg['Servers'][$i]['port'] = '3306';
    $cfg['Servers'][$i]['hide_db'] = 'information_schema';
    $cfg['Servers'][$i]['ssl'] = false;
    $cfg['Servers'][$i]['extension'] = 'mysqli';
    $cfg['Servers'][$i]['compress'] = false;
    $cfg['Servers'][$i]['AllowNoPassword'] = false;
    $cfg['Servers'][$i]['controlhost'] = $host;
    $cfg['Servers'][$i]['controlport'] = '3306';
    $cfg['Servers'][$i]['controluser'] = '<controluser>';
    $cfg['Servers'][$i]['controlpass'] = '<controlpass>';
    $cfg['Servers'][$i]['auth_type'] = 'cookie';
    $cfg['Servers'][$i]['pmadb'] = 'phpmyadmin';
    $cfg['Servers'][$i]['bookmarktable'] = 'pma__bookmark';
    $cfg['Servers'][$i]['relation'] = 'pma__relation';
    $cfg['Servers'][$i]['table_info'] = 'pma__table_info';
    $cfg['Servers'][$i]['table_coords'] = 'pma__table_coords';
    $cfg['Servers'][$i]['pdf_pages'] = 'pma__pdf_pages';
    $cfg['Servers'][$i]['column_info'] = 'pma__column_info';
    $cfg['Servers'][$i]['history'] = 'pma__history';
    $cfg['Servers'][$i]['table_uiprefs'] = 'pma__table_uiprefs';
    $cfg['Servers'][$i]['tracking'] = 'pma__tracking';
    $cfg['Servers'][$i]['userconfig'] = 'pma__userconfig';
    $cfg['Servers'][$i]['recent'] = 'pma__recent';
    $cfg['Servers'][$i]['favorite'] = 'pma__favorite';
    $cfg['Servers'][$i]['users'] = 'pma__users';
    $cfg['Servers'][$i]['usergroups'] = 'pma__usergroups';
    $cfg['Servers'][$i]['navigationhiding'] = 'pma__navigationhiding';
    $cfg['Servers'][$i]['savedsearches'] = 'pma__savedsearches';
    $cfg['Servers'][$i]['central_columns'] = 'pma__central_columns';
    $cfg['Servers'][$i]['designer_settings'] = 'pma__designer_settings';
    $cfg['Servers'][$i]['export_templates'] = 'pma__export_templates';
}

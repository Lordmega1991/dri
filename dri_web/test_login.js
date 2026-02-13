
const { createClient } = require('@supabase/supabase-js');

// Use hardcoded values to test direct access
const supabaseUrl = 'https://gptrgiilbdpnnftovpfs.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdwdHJnaWlsYmRwbm5mdG92cGZzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk0MjI0OTMsImV4cCI6MjA3NDk5ODQ5M30.VxEQNzbtkKQ4ffBpqZBiik6ctGxcZNGD0aav6YPJ9a4';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testLogin() {
    console.log('Testing login with login: "d6ZLtE" and password: "0osWi6"');

    const { data, error } = await supabase
        .from('dados_defesas')
        .select('*')
        .eq('login', 'd6ZLtE')
        .eq('senha', '0osWi6');

    if (error) {
        console.error('Error fetching data:', error);
    } else {
        console.log('Login Result:', data);
        if (data.length === 0) {
            console.log('No record found! This might be a Row Level Security (RLS) issue.');
        } else {
            console.log('Record found successfully!');
        }
    }
}

testLogin();

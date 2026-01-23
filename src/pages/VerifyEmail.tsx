import React, { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { CheckCircle, XCircle, Loader, Mail } from 'lucide-react';
import { supabase } from '../lib/supabase';

const VerifyEmail: React.FC = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');
  const [message, setMessage] = useState('');
  const [resending, setResending] = useState(false);
  const [resendSuccess, setResendSuccess] = useState(false);

  useEffect(() => {
    const token = searchParams.get('token');

    if (!token) {
      setStatus('error');
      setMessage('Kein Verifizierungstoken gefunden.');
      return;
    }

    const verifyEmail = async () => {
      try {
        const response = await fetch(
          `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/verify-email`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
            },
            body: JSON.stringify({ token }),
          }
        );

        const data = await response.json();
        console.log('Response status:', response.status);
        console.log('Response data:', data);

        if (response.ok && data.success) {
          setStatus('success');
          setMessage('Ihre E-Mail-Adresse wurde erfolgreich bestätigt!');
          setTimeout(() => navigate('/auth'), 3000);
        } else {
          setStatus('error');
          const errorMsg = data.error || 'Fehler bei der Verifizierung.';
          const details = data.details ? ` Details: ${data.details}` : '';
          const type = data.type ? ` (${data.type})` : '';
          setMessage(errorMsg + details + type);
          console.error('Verification failed:', data);
        }
      } catch (error) {
        console.error('Verification error:', error);
        setStatus('error');
        setMessage(`Ein Fehler ist aufgetreten: ${error.message || String(error)}`);
      }
    };

    verifyEmail();
  }, [searchParams, navigate]);

  const handleResendEmail = async () => {
    setResending(true);
    setResendSuccess(false);

    try {
      const { data: { user } } = await supabase.auth.getUser();

      if (!user) {
        setMessage('Sie müssen angemeldet sein, um eine neue Verifizierungs-E-Mail anzufordern.');
        setResending(false);
        return;
      }

      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-verification-email`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
          },
          body: JSON.stringify({
            userId: user.id,
            email: user.email,
          }),
        }
      );

      if (response.ok) {
        setResendSuccess(true);
        setMessage('Eine neue Verifizierungs-E-Mail wurde an Ihre E-Mail-Adresse gesendet. Bitte überprüfen Sie Ihr Postfach.');
      } else {
        const errorData = await response.json();
        setMessage(`Fehler beim Senden der E-Mail: ${errorData.error || 'Unbekannter Fehler'}`);
      }
    } catch (error) {
      console.error('Error resending email:', error);
      setMessage(`Fehler beim Senden der E-Mail: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setResending(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white rounded-lg shadow-lg p-8">
        <div className="text-center">
          {status === 'loading' && (
            <>
              <Loader className="w-16 h-16 text-teal-600 mx-auto mb-4 animate-spin" />
              <h1 className="text-2xl font-bold text-gray-900 mb-2">
                E-Mail wird verifiziert...
              </h1>
              <p className="text-gray-600">
                Bitte warten Sie einen Moment.
              </p>
            </>
          )}

          {status === 'success' && (
            <>
              <CheckCircle className="w-16 h-16 text-green-600 mx-auto mb-4" />
              <h1 className="text-2xl font-bold text-gray-900 mb-2">
                Erfolgreich verifiziert!
              </h1>
              <p className="text-gray-600 mb-6">
                {message}
              </p>
              <p className="text-sm text-gray-500">
                Sie werden in Kürze zur Anmeldeseite weitergeleitet...
              </p>
            </>
          )}

          {status === 'error' && (
            <>
              {resendSuccess ? (
                <>
                  <Mail className="w-16 h-16 text-green-600 mx-auto mb-4" />
                  <h1 className="text-2xl font-bold text-gray-900 mb-2">
                    E-Mail gesendet!
                  </h1>
                  <p className="text-gray-600 mb-6">
                    {message}
                  </p>
                  <p className="text-sm text-gray-500 mb-4">
                    Bitte überprüfen Sie auch Ihren Spam-Ordner.
                  </p>
                  <button
                    onClick={() => navigate('/auth')}
                    className="w-full bg-teal-600 text-white py-3 rounded-lg hover:bg-teal-700 transition-colors"
                  >
                    Zur Anmeldung
                  </button>
                </>
              ) : (
                <>
                  <XCircle className="w-16 h-16 text-red-600 mx-auto mb-4" />
                  <h1 className="text-2xl font-bold text-gray-900 mb-2">
                    Verifizierung fehlgeschlagen
                  </h1>
                  <p className="text-gray-600 mb-6">
                    {message}
                  </p>
                  <div className="space-y-3">
                    <button
                      onClick={handleResendEmail}
                      disabled={resending}
                      className="w-full bg-teal-600 text-white py-3 rounded-lg hover:bg-teal-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                    >
                      {resending ? (
                        <>
                          <Loader className="w-5 h-5 animate-spin" />
                          Wird gesendet...
                        </>
                      ) : (
                        <>
                          <Mail className="w-5 h-5" />
                          Neue Verifizierungs-E-Mail senden
                        </>
                      )}
                    </button>
                    <button
                      onClick={() => navigate('/auth')}
                      className="w-full border border-gray-300 text-gray-700 py-3 rounded-lg hover:bg-gray-50 transition-colors"
                    >
                      Zur Anmeldung
                    </button>
                  </div>
                </>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default VerifyEmail;

import React, { useEffect, useState, useRef } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Calendar, Clock, MapPin, Users, Plus, Edit, Trash2, Eye, AlertCircle, X, UserCheck, XCircle } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';
import { Course, Registration } from '../types';
import { format, parseISO, isToday, isTomorrow } from 'date-fns';
import { de } from 'date-fns/locale';

interface CourseWithRegistration extends Course {
  registration?: Registration;
  teacher?: { first_name: string; last_name: string };
}

const MyCourses: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { userProfile } = useAuth();
  const [teachingCourses, setTeachingCourses] = useState<Course[]>([]);
  const [enrolledCourses, setEnrolledCourses] = useState<CourseWithRegistration[]>([]);
  const [loading, setLoading] = useState(true);
  const [successMessage, setSuccessMessage] = useState('');
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [courseToDelete, setCourseToDelete] = useState<{ id: string; title: string; series_id: string | null } | null>(null);
  const [seriesCount, setSeriesCount] = useState(0);
  const [deleteScope, setDeleteScope] = useState<'single' | 'series'>('single');
  const [cancellingCourse, setCancellingCourse] = useState<string | null>(null);
  const successTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const isTeacher = userProfile?.roles?.includes('course_leader') || userProfile?.roles?.includes('admin');

  useEffect(() => {
    let isMounted = true;

    const fetchMyCourses = async () => {
      if (!userProfile) return;

      try {
        const { data: registrations, error: regError } = await supabase
          .from('registrations')
          .select(`
            *,
            course:courses(
              *,
              teacher:users!courses_teacher_id_fkey(first_name, last_name)
            )
          `)
          .eq('user_id', userProfile.id)
          .neq('status', 'cancelled')
          .order('registered_at', { ascending: false });

        if (regError) throw regError;

        const enrolledData: CourseWithRegistration[] = (registrations || [])
          .filter((r: any) => r.course)
          .map((r: any) => ({
            ...r.course,
            registration: {
              id: r.id,
              course_id: r.course_id,
              user_id: r.user_id,
              status: r.status,
              is_waitlist: r.is_waitlist,
              waitlist_position: r.waitlist_position,
              registered_at: r.registered_at
            },
            teacher: r.course.teacher
          }));

        if (isMounted) {
          setEnrolledCourses(enrolledData);
        }

        if (isTeacher) {
          const { data: teachingData, error: teachingError } = await supabase
            .from('courses')
            .select(`
              *,
              teacher:users!courses_teacher_id_fkey(first_name, last_name),
              registrations:registrations(user_id, status, is_waitlist)
            `)
            .eq('teacher_id', userProfile.id)
            .order('date', { ascending: true })
            .order('time', { ascending: true });

          if (teachingError) throw teachingError;
          if (isMounted) {
            setTeachingCourses(teachingData || []);
          }
        }
      } catch (error) {
        console.error('Error fetching courses:', error);
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    fetchMyCourses();

    if (location.state?.message) {
      setSuccessMessage(location.state.message);
      if (successTimeoutRef.current) {
        clearTimeout(successTimeoutRef.current);
      }
      successTimeoutRef.current = setTimeout(() => setSuccessMessage(''), 5000);
    }

    return () => {
      isMounted = false;
      if (successTimeoutRef.current) {
        clearTimeout(successTimeoutRef.current);
      }
    };
  }, [userProfile, location.state, isTeacher]);

  const handleCancelRegistration = async (courseId: string, courseTitle: string) => {
    if (!confirm(`Möchten Sie Ihre Anmeldung für "${courseTitle}" wirklich stornieren?`)) {
      return;
    }

    setCancellingCourse(courseId);
    try {
      const { data, error } = await supabase.rpc('unregister_from_course', {
        p_course_id: courseId,
        p_user_id: userProfile?.id
      });

      if (error) throw error;

      if (data && !data.success) {
        throw new Error(data.message || 'Stornierung fehlgeschlagen');
      }

      setEnrolledCourses(prev => prev.filter(c => c.id !== courseId));
      setSuccessMessage('Anmeldung erfolgreich storniert!');
      if (successTimeoutRef.current) {
        clearTimeout(successTimeoutRef.current);
      }
      successTimeoutRef.current = setTimeout(() => setSuccessMessage(''), 5000);
    } catch (error) {
      console.error('Error cancelling registration:', error);
      alert('Fehler beim Stornieren der Anmeldung. Bitte versuchen Sie es erneut.');
    } finally {
      setCancellingCourse(null);
    }
  };

  const handleDeleteClick = async (courseId: string, courseTitle: string, seriesId: string | null) => {
    if (!seriesId) {
      if (!confirm(`Möchten Sie den Kurs "${courseTitle}" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.`)) {
        return;
      }
      await deleteCourse(courseId, 'single');
      return;
    }

    try {
      const { count } = await supabase
        .from('courses')
        .select('*', { count: 'exact', head: true })
        .eq('series_id', seriesId);

      setSeriesCount(count || 0);
      setCourseToDelete({ id: courseId, title: courseTitle, series_id: seriesId });
      setDeleteScope('single');
      setDeleteDialogOpen(true);
    } catch (error) {
      console.error('Error checking series:', error);
      alert('Fehler beim Überprüfen der Serie. Bitte versuchen Sie es erneut.');
    }
  };

  const handleConfirmDelete = async () => {
    if (!courseToDelete) return;

    await deleteCourse(courseToDelete.id, deleteScope);
    setDeleteDialogOpen(false);
    setCourseToDelete(null);
  };

  const deleteCourse = async (courseId: string, scope: 'single' | 'series') => {
    try {
      if (scope === 'series' && courseToDelete?.series_id) {
        const { error } = await supabase
          .from('courses')
          .delete()
          .eq('series_id', courseToDelete.series_id);

        if (error) throw error;

        setTeachingCourses(teachingCourses.filter(course => course.series_id !== courseToDelete.series_id));
        setSuccessMessage(`Alle ${seriesCount} Kurse der Serie wurden erfolgreich gelöscht!`);
      } else {
        const { error } = await supabase
          .from('courses')
          .delete()
          .eq('id', courseId);

        if (error) throw error;

        setTeachingCourses(teachingCourses.filter(course => course.id !== courseId));
        setSuccessMessage('Kurs erfolgreich gelöscht!');
      }

      if (successTimeoutRef.current) {
        clearTimeout(successTimeoutRef.current);
      }
      successTimeoutRef.current = setTimeout(() => setSuccessMessage(''), 5000);
    } catch (error) {
      console.error('Error deleting course:', error);
      alert('Fehler beim Löschen des Kurses. Bitte versuchen Sie es erneut.');
    }
  };

  const formatDate = (dateString: string) => {
    try {
      const date = parseISO(dateString);
      if (isToday(date)) {
        return 'Heute';
      } else if (isTomorrow(date)) {
        return 'Morgen';
      }
      return format(date, 'dd.MM.yyyy', { locale: de });
    } catch {
      return dateString;
    }
  };

  const isPastCourse = (dateString: string, timeString?: string) => {
    try {
      const now = new Date();
      const courseDate = parseISO(dateString);
      if (timeString) {
        const [hours, minutes] = timeString.split(':').map(Number);
        courseDate.setHours(hours || 0, minutes || 0, 0, 0);
      } else {
        courseDate.setHours(23, 59, 59, 999);
      }
      return courseDate < now;
    } catch {
      return false;
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-teal-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {successMessage && (
        <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
          <p className="text-sm text-green-600">{successMessage}</p>
        </div>
      )}

      <section>
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Meine Anmeldungen</h1>
            <p className="text-gray-600">Kurse, für die Sie angemeldet sind</p>
          </div>
          <button
            onClick={() => navigate('/courses')}
            className="mt-4 sm:mt-0 bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors flex items-center"
          >
            <Plus className="w-4 h-4 mr-2" />
            Weitere Kurse
          </button>
        </div>

        {enrolledCourses.length === 0 ? (
          <div className="text-center py-12 bg-white rounded-lg shadow-sm border border-gray-200">
            <UserCheck className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">Keine Anmeldungen</h3>
            <p className="text-gray-600 mb-6">Sie sind aktuell für keine Kurse angemeldet.</p>
            <button
              onClick={() => navigate('/courses')}
              className="bg-teal-600 text-white px-6 py-3 rounded-lg hover:bg-teal-700 transition-colors"
            >
              Kurse durchsuchen
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {enrolledCourses.map((course) => {
              const isPast = isPastCourse(course.date, course.time);
              const isWaitlist = course.registration?.is_waitlist || course.registration?.status === 'waitlist';

              return (
                <div key={course.id} className={`bg-white rounded-lg shadow-sm border overflow-hidden hover:shadow-md transition-shadow ${isPast ? 'border-gray-300 opacity-75' : 'border-gray-200'}`}>
                  <div className="p-6">
                    <div className="flex items-start justify-between mb-4">
                      <h3 className="text-lg font-semibold text-gray-900 line-clamp-2">{course.title}</h3>
                      <span className={`px-2 py-1 text-xs font-semibold rounded-full ${
                        isWaitlist
                          ? 'bg-yellow-100 text-yellow-800'
                          : 'bg-green-100 text-green-800'
                      }`}>
                        {isWaitlist
                          ? course.registration?.waitlist_position
                            ? `Warteliste #${course.registration.waitlist_position}`
                            : 'Warteliste'
                          : 'Angemeldet'}
                      </span>
                    </div>

                    <p className="text-gray-600 text-sm mb-4 line-clamp-2">{course.description}</p>

                    <div className="space-y-2 mb-4">
                      <div className="flex items-center text-sm text-gray-600">
                        <Calendar className="w-4 h-4 mr-2" />
                        {formatDate(course.date)}
                      </div>
                      <div className="flex items-center text-sm text-gray-600">
                        <Clock className="w-4 h-4 mr-2" />
                        {course.time}{course.end_time && ` - ${course.end_time}`}
                      </div>
                      <div className="flex items-center text-sm text-gray-600">
                        <MapPin className="w-4 h-4 mr-2" />
                        {course.location}
                      </div>
                      {course.teacher && (
                        <div className="flex items-center text-sm text-gray-600">
                          <Users className="w-4 h-4 mr-2" />
                          {course.teacher.first_name} {course.teacher.last_name}
                        </div>
                      )}
                    </div>

                    <div className="flex items-center justify-between mb-4">
                      <span className="text-xl font-bold text-teal-600">{course.price}€</span>
                      {isPast && (
                        <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">Vergangen</span>
                      )}
                    </div>

                    {!isPast && (
                      <div className="pt-4 border-t border-gray-200">
                        <button
                          onClick={() => handleCancelRegistration(course.id, course.title)}
                          disabled={cancellingCourse === course.id}
                          className="w-full flex items-center justify-center px-4 py-2 text-red-600 border border-red-200 rounded-lg hover:bg-red-50 transition-colors disabled:opacity-50"
                        >
                          {cancellingCourse === course.id ? (
                            <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-red-600 mr-2"></div>
                          ) : (
                            <XCircle className="w-4 h-4 mr-2" />
                          )}
                          Anmeldung stornieren
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>

      {isTeacher && (
        <section>
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6">
            <div>
              <h2 className="text-2xl font-bold text-gray-900">Von mir erstellte Kurse</h2>
              <p className="text-gray-600">Verwalten Sie Ihre Yoga-Kurse</p>
            </div>

            <button
              onClick={() => navigate('/create-course')}
              className="mt-4 sm:mt-0 bg-teal-600 text-white px-4 py-2 rounded-lg hover:bg-teal-700 transition-colors flex items-center"
            >
              <Plus className="w-4 h-4 mr-2" />
              Neuer Kurs
            </button>
          </div>

          {teachingCourses.length === 0 ? (
            <div className="text-center py-12 bg-white rounded-lg shadow-sm border border-gray-200">
              <Calendar className="w-16 h-16 text-gray-300 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">Keine Kurse erstellt</h3>
              <p className="text-gray-600 mb-6">Sie haben noch keine Kurse erstellt.</p>
              <button
                onClick={() => navigate('/create-course')}
                className="bg-teal-600 text-white px-6 py-3 rounded-lg hover:bg-teal-700 transition-colors flex items-center mx-auto"
              >
                <Plus className="w-4 h-4 mr-2" />
                Ersten Kurs erstellen
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {teachingCourses.map((course) => {
                const registeredCount = course.registrations?.filter((r: any) => r.status === 'registered' && !r.is_waitlist).length || 0;
                const waitlistCount = course.registrations?.filter((r: any) => r.status === 'waitlist' && r.is_waitlist).length || 0;
                const isFull = registeredCount >= (course.max_participants || 0);
                const isPast = isPastCourse(course.date, course.time);

                return (
                  <div key={course.id} className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow">
                    <div className="p-6">
                      <div className="flex items-start justify-between mb-4">
                        <h3 className="text-lg font-semibold text-gray-900 line-clamp-2">{course.title}</h3>
                        <span className="text-xl font-bold text-teal-600">{course.price}€</span>
                      </div>

                      <p className="text-gray-600 text-sm mb-4 line-clamp-3">{course.description}</p>

                      <div className="space-y-2 mb-4">
                        <div className="flex items-center text-sm text-gray-600">
                          <Calendar className="w-4 h-4 mr-2" />
                          {formatDate(course.date)}
                        </div>
                        <div className="flex items-center text-sm text-gray-600">
                          <Clock className="w-4 h-4 mr-2" />
                          {course.time}{course.end_time && ` - ${course.end_time}`}
                          {course.duration && ` (${course.duration} Min.)`}
                        </div>
                        <div className="flex items-center text-sm text-gray-600">
                          <MapPin className="w-4 h-4 mr-2" />
                          {course.location}
                        </div>
                        <div className="flex items-center text-sm text-gray-600">
                          <Users className="w-4 h-4 mr-2" />
                          {registeredCount}/{course.max_participants} Teilnehmer
                          {waitlistCount > 0 && (
                            <span className="ml-2 px-2 py-0.5 text-xs bg-yellow-100 text-yellow-800 rounded-full">
                              +{waitlistCount} Wartend
                            </span>
                          )}
                        </div>
                      </div>

                      <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center">
                          <div className={`w-3 h-3 rounded-full mr-2 ${
                            isPast ? 'bg-gray-400' : isFull ? 'bg-red-500' : (course.max_participants - registeredCount <= 2 ? 'bg-yellow-500' : 'bg-green-500')
                          }`}></div>
                          <span className="text-xs text-gray-600">
                            {isPast ? 'Vergangen' : isFull ? 'Ausgebucht' : (course.max_participants - registeredCount <= 2 ? `noch ${course.max_participants - registeredCount} ${course.max_participants - registeredCount === 1 ? 'Restplatz' : 'Restplätze'}` : 'Verfügbar')}
                          </span>
                        </div>
                      </div>

                      <div className="flex items-center justify-between pt-4 border-t border-gray-200">
                        <button
                          onClick={() => navigate(`/course/${course.id}/participants`)}
                          className="flex items-center text-teal-600 hover:text-teal-700 text-sm"
                        >
                          <Eye className="w-4 h-4 mr-1" />
                          Teilnehmer
                        </button>

                        <div className="flex items-center space-x-2">
                          <button
                            onClick={() => navigate(`/course/${course.id}/edit`)}
                            className="p-2 text-gray-400 hover:text-blue-600 transition-colors"
                            title="Bearbeiten"
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleDeleteClick(course.id, course.title, course.series_id)}
                            className="p-2 text-gray-400 hover:text-red-600 transition-colors"
                            title="Löschen"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>
      )}

      {deleteDialogOpen && courseToDelete && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
          <div className="bg-white rounded-lg shadow-xl max-w-lg w-full mx-4">
            <div className="p-6">
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-start">
                  <AlertCircle className="w-6 h-6 text-red-600 mr-3 flex-shrink-0 mt-0.5" />
                  <div>
                    <h3 className="text-lg font-semibold text-gray-900 mb-1">
                      Kurs löschen
                    </h3>
                    <p className="text-sm text-gray-600">
                      {courseToDelete.title}
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setDeleteDialogOpen(false)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {seriesCount > 1 ? (
                <div className="space-y-4">
                  <div className="p-4 bg-amber-50 border border-amber-200 rounded-lg">
                    <p className="text-sm text-amber-900">
                      Dieser Kurs ist Teil einer Serie mit {seriesCount} Terminen.
                      Möchten Sie nur diesen Termin oder alle Termine der Serie löschen?
                    </p>
                  </div>

                  <div className="space-y-2">
                    <label className="flex items-start p-4 border-2 border-gray-200 rounded-lg cursor-pointer hover:bg-gray-50 transition-colors">
                      <input
                        type="radio"
                        value="single"
                        checked={deleteScope === 'single'}
                        onChange={(e) => setDeleteScope(e.target.value as 'single' | 'series')}
                        className="w-4 h-4 text-red-600 border-gray-300 focus:ring-red-500 mt-0.5"
                      />
                      <div className="ml-3">
                        <span className="block text-sm font-medium text-gray-900">
                          Nur diesen Termin löschen
                        </span>
                        <span className="block text-sm text-gray-600 mt-1">
                          Die anderen Termine der Serie bleiben bestehen.
                        </span>
                      </div>
                    </label>

                    <label className="flex items-start p-4 border-2 border-gray-200 rounded-lg cursor-pointer hover:bg-gray-50 transition-colors">
                      <input
                        type="radio"
                        value="series"
                        checked={deleteScope === 'series'}
                        onChange={(e) => setDeleteScope(e.target.value as 'single' | 'series')}
                        className="w-4 h-4 text-red-600 border-gray-300 focus:ring-red-500 mt-0.5"
                      />
                      <div className="ml-3">
                        <span className="block text-sm font-medium text-gray-900">
                          Alle {seriesCount} Termine der Serie löschen
                        </span>
                        <span className="block text-sm text-gray-600 mt-1">
                          Alle Termine dieser Serie werden unwiderruflich gelöscht.
                        </span>
                      </div>
                    </label>
                  </div>

                  <div className="p-4 bg-red-50 border border-red-200 rounded-lg">
                    <p className="text-sm text-red-800 font-medium">
                      Diese Aktion kann nicht rückgängig gemacht werden!
                    </p>
                  </div>
                </div>
              ) : (
                <div className="space-y-4">
                  <p className="text-sm text-gray-600">
                    Möchten Sie diesen Kurs wirklich löschen?
                  </p>
                  <div className="p-4 bg-red-50 border border-red-200 rounded-lg">
                    <p className="text-sm text-red-800 font-medium">
                      Diese Aktion kann nicht rückgängig gemacht werden!
                    </p>
                  </div>
                </div>
              )}

              <div className="flex items-center justify-end space-x-3 mt-6 pt-6 border-t border-gray-200">
                <button
                  onClick={() => setDeleteDialogOpen(false)}
                  className="px-4 py-2 text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
                >
                  Abbrechen
                </button>
                <button
                  onClick={handleConfirmDelete}
                  className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
                >
                  {deleteScope === 'series' && seriesCount > 1
                    ? `Alle ${seriesCount} Termine löschen`
                    : 'Kurs löschen'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default MyCourses;

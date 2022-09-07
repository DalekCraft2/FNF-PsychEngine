#ifndef LIBVLC_H
#define LIBVLC_H

#include <iostream>
#include <vlc/vlc.h>
#include <mutex>

namespace vlc
{
	class LibVLC
	{
	public:
		uint8_t *pixelData;
		float flags[19] = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};

		LibVLC::LibVLC()
		{
			libVlcInstance = libvlc_new(0, NULL);
		}

		LibVLC::~LibVLC()
		{
			// libvlc_event_manager_t *eventManager = libvlc_media_player_event_manager(mediaPlayer);
			// if (eventManager != nullptr)
			// {
			// 	// libvlc_event_detach(eventManager, libvlc_MediaPlayerMediaChanged, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerNothingSpecial, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerOpening, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerBuffering, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerPlaying, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerPaused, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerStopped, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerForward, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerBackward, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerEndReached, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerEncounteredError, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerTimeChanged, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerPositionChanged, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerSeekableChanged, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerPausableChanged, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerTitleChanged, callbacks, this);
			// 	// libvlc_event_detach(eventManager, libvlc_MediaPlayerSnapshotTaken, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerLengthChanged, callbacks, this);
			// 	libvlc_event_detach(eventManager, libvlc_MediaPlayerVout, callbacks, this);
			// }

			libvlc_media_player_release(mediaPlayer);
			libvlc_release(libVlcInstance);

			if (pixelData != nullptr)
				delete pixelData;
		}

		void setPath(const char *path)
		{
			libvlc_media_t *media = libvlc_media_new_path(libVlcInstance, path);
			mediaPlayer = libvlc_media_player_new(libVlcInstance);
			libvlc_media_player_set_media(mediaPlayer, media);
			libvlc_media_release(media);

			initCallbacks();
			registerEvents();
		}

		void play()
		{
			// if (pixelData != nullptr)
			// 	delete pixelData;
			pixelData = nullptr;

			if (mediaPlayer != nullptr)
				libvlc_media_player_play(mediaPlayer);
		}

		void play(const char *path)
		{
			setPath(path);
			play();
		}

		void stop()
		{
			if (mediaPlayer != nullptr)
				libvlc_media_player_stop(mediaPlayer);
		}

		void pause()
		{
			if (mediaPlayer != nullptr)
				libvlc_media_player_set_pause(mediaPlayer, true);
		}

		void resume()
		{
			if (mediaPlayer != nullptr)
				libvlc_media_player_set_pause(mediaPlayer, false);
		}

		void togglePause()
		{
			if (mediaPlayer != nullptr)
				libvlc_media_player_pause(mediaPlayer);
		}

		bool getFullscreen()
		{
			if (mediaPlayer != nullptr)
				return libvlc_get_fullscreen(mediaPlayer);
			return false;
		}

		void setFullscreen(bool fullscreen)
		{
			if (mediaPlayer != nullptr)
				libvlc_set_fullscreen(mediaPlayer, fullscreen);
		}

		libvlc_time_t getLength()
		{
			if (mediaPlayer != nullptr)
				return libvlc_media_player_get_length(mediaPlayer);
			return 0;
		}

		int getWidth()
		{
			if (mediaPlayer != nullptr)
				return libvlc_video_get_width(mediaPlayer);
			return 0;
		}

		int getHeight()
		{
			if (mediaPlayer != nullptr)
				return libvlc_video_get_height(mediaPlayer);
			return 0;
		}

		bool isPlaying()
		{
			if (mediaPlayer != nullptr)
				return libvlc_media_player_is_playing(mediaPlayer);
			return false;
		}

		bool isSeekable()
		{
			if (mediaPlayer != nullptr)
				return libvlc_media_player_is_seekable(mediaPlayer);
			return false;
		}

		float getVolume()
		{
			if (mediaPlayer != nullptr)
				return libvlc_audio_get_volume(mediaPlayer);
			return 0;
		}

		void setVolume(float volume)
		{
			if (volume > 100)
				volume = 100;
			if (volume < 0)
				volume = 0;

			if (mediaPlayer != nullptr)
				libvlc_audio_set_volume(mediaPlayer, volume);
		}

		libvlc_time_t getTime()
		{
			if (mediaPlayer != nullptr)
				return libvlc_media_player_get_time(mediaPlayer);
			return 0;
		}

		void setTime(libvlc_time_t time)
		{
			if (mediaPlayer != nullptr)
				libvlc_media_player_set_time(mediaPlayer, time);
		}

		float getPosition()
		{
			if (mediaPlayer != nullptr)
				return libvlc_media_player_get_position(mediaPlayer);
			return 0;
		}

		void setPosition(float position)
		{
			if (mediaPlayer != nullptr)
				libvlc_media_player_set_position(mediaPlayer, position);
		}

		uint8_t *getPixelData()
		{
			return pixelData;
		}

		void nextFrame()
		{
			if (mediaPlayer != nullptr)
				libvlc_media_player_next_frame(mediaPlayer);
		}

		uint32_t getVOutCount()
		{
			if (mediaPlayer != nullptr)
				return libvlc_media_player_has_vout(mediaPlayer);
			return false;
		}

		float getFlag(int index)
		{
			if (index < sizeof(flags))
				return flags[index];
			return 0;
		}

		void setFlag(int index, float value)
		{
			if (index < sizeof(flags))
				flags[index] = value;
		}

	private:
		libvlc_instance_t *libVlcInstance;
		libvlc_media_player_t *mediaPlayer;

		static void callbacks(const libvlc_event_t *event, void *ptr)
		{
			LibVLC *self = (LibVLC *)ptr;

			switch (event->type)
			{
				// TODO Add this
			// case libvlc_MediaPlayerMediaChanged:
			// 	self->flags[0] = event->u.media_player_media_changed.new_media;
			// 	break;
			case libvlc_MediaPlayerNothingSpecial:
				self->flags[1] = 1;
				break;
			case libvlc_MediaPlayerOpening:
				self->flags[2] = 1;
				break;
			case libvlc_MediaPlayerBuffering:
				self->flags[3] = event->u.media_player_buffering.new_cache;
				break;
			case libvlc_MediaPlayerPlaying:
				self->flags[4] = 1;
				break;
			case libvlc_MediaPlayerPaused:
				self->flags[5] = 1;
				break;
			case libvlc_MediaPlayerStopped:
				self->flags[6] = 1;
				break;
			case libvlc_MediaPlayerForward:
				self->flags[7] = 1;
				break;
			case libvlc_MediaPlayerBackward:
				self->flags[8] = 1;
				break;
			case libvlc_MediaPlayerEndReached:
				self->flags[9] = 1;
				break;
			case libvlc_MediaPlayerEncounteredError:
				self->flags[10] = 1;
				break;
			case libvlc_MediaPlayerTimeChanged:
				self->flags[11] = event->u.media_player_time_changed.new_time;
				break;
			case libvlc_MediaPlayerPositionChanged:
				self->flags[12] = event->u.media_player_position_changed.new_position;
				break;
			case libvlc_MediaPlayerSeekableChanged:
				self->flags[13] = event->u.media_player_seekable_changed.new_seekable;
				break;
			case libvlc_MediaPlayerPausableChanged:
				self->flags[14] = event->u.media_player_pausable_changed.new_pausable;
				break;
			case libvlc_MediaPlayerTitleChanged:
				self->flags[15] = event->u.media_player_title_changed.new_title;
				break;
				// TODO Add this
			// case libvlc_MediaPlayerSnapshotTaken:
			// 	self->flags[16] = event->u.media_player_snapshot_taken.psz_filename;
			// 	break;
			case libvlc_MediaPlayerLengthChanged:
				self->flags[17] = event->u.media_player_length_changed.new_length;
				break;
			case libvlc_MediaPlayerVout:
				self->flags[18] = event->u.media_player_vout.new_count;
				break;
			}
		}

		void registerEvents()
		{
			if (mediaPlayer != nullptr)
			{
				libvlc_event_manager_t *eventManager = libvlc_media_player_event_manager(mediaPlayer);
				if (eventManager != nullptr)
				{
					// libvlc_event_attach(eventManager, libvlc_MediaPlayerMediaChanged, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerNothingSpecial, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerOpening, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerBuffering, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerPlaying, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerPaused, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerStopped, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerForward, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerBackward, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerEndReached, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerEncounteredError, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerTimeChanged, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerPositionChanged, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerSeekableChanged, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerPausableChanged, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerTitleChanged, callbacks, this);
					// libvlc_event_attach(eventManager, libvlc_MediaPlayerSnapshotTaken, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerLengthChanged, callbacks, this);
					libvlc_event_attach(eventManager, libvlc_MediaPlayerVout, callbacks, this);
				}
			}
		}

		void initCallbacks()
		{
			if (mediaPlayer != nullptr)
			{
				libvlc_video_set_format_callbacks(mediaPlayer, setupVideo, cleanupVideo);
				libvlc_video_set_callbacks(mediaPlayer, lockVideo, unlockVideo, displayVideo, this);
			}
		}

		static void *lockVideo(void *opaque, void **planes)
		{
			LibVLC *self = (LibVLC *)opaque;
			*planes = self->pixelData;
			return NULL;
		}

		static void unlockVideo(void *opaque, void *picture, void *const *planes)
		{
			LibVLC *self = (LibVLC *)opaque;
		}

		static void displayVideo(void *opaque, void *picture)
		{
		}

		static uint32_t setupVideo(void **opaque, char *chroma, uint32_t *width, uint32_t *height, uint32_t *pitches, uint32_t *lines)
		{
			LibVLC *self = (LibVLC *)*opaque;

			uint32_t _width = *width;
			uint32_t _height = *height;
			uint32_t _pitch = _width * 4;
			uint32_t _frame = _width * _height * 4;

			*pitches = _pitch;
			*lines = _height;
			memcpy(chroma, "RV32", 4);

			if (self->pixelData != nullptr)
				delete self->pixelData;
			self->pixelData = new uint8_t[_frame];
			return 1; // One color plane
		}

		static void cleanupVideo(void *opaque)
		{
		}
	};
}
#endif

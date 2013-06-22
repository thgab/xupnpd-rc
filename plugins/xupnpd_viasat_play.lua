-- thgab74 at gmail.com
-- Licensed under GNU GPL version 2 
-- https://www.gnu.org/licenses/gpl-2.0.html
cfg.viasat_play_video_count=100

function viasat_play_updatefeed(feed,friendly_name)
	local rc=false
	local feed_name='viasat_play_'..string.gsub(feed,'/','_')
	local feed_m3u_path=cfg.feeds_path..feed_name..'.m3u'
	local tmp_m3u_path=cfg.tmp_path..feed_name..'.m3u'
	local feed_url= 'http://play.viasat.hu/series/'..feed

	local dfd=io.open(tmp_m3u_path,'w+')

	if dfd then
		dfd:write('#EXTM3U name=\"',friendly_name or feed_name,'\" type=mp4 plugin=viasat_play\n')

		if cfg.debug>0 then print('viasat_play try url '..feed_url) end

		local feed_data=http.download(feed_url)

		if feed_data then

			for urn,logo,name in string.gmatch(feed_data,'.-<a class="image" href="(.-)">%s*<img src="(.-)" />%s*</a>%s*<div class="info">%s*<a class="title" href=".-">(.-)</a>%s*<a class="lead">.-') do
				dfd:write('#EXTINF:0 logo=',logo,' ,',name,'\n','',urn,'\n')
			end                 

			feed_data=nil
		end


		dfd:close()

		if util.md5(tmp_m3u_path)~=util.md5(feed_m3u_path) then
			if os.rename(tmp_m3u_path,feed_m3u_path) then
				if cfg.debug>0 then print('viasat play feed \''..feed_name..'\' updated') end
				rc=true
			end
		else
			util.unlink(tmp_m3u_path)
		end
	end

	return rc
end




function viasat_play_sendurl(viasat_play_url,range)
	local url=nil
	-- if plugin_sendurl_from_cache(viasat_play_url,range) then return end
	local clip_page=plugin_download(viasat_play_url)
	if clip_page then
		local video_url=string.match(clip_page,'.- video_src = "(.-)";.-')
		if video_url then
			plugin_sendurl(viasat_play_url,video_url,range)
		end
	end
	if cfg.debug>0 then print('viasat_play clip is not found') end
	plugin_sendfile('www/corrupted.mp4')
end

plugins['viasat_play']={}
plugins.viasat_play.name="viasat_play"
plugins.viasat_play.desc="serie url without part : http://play.viasat.hu/series/" 
plugins.viasat_play.sendurl=viasat_play_sendurl
plugins.viasat_play.updatefeed=viasat_play_updatefeed
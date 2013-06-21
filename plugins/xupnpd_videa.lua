-- thgab74 at gmail.com
-- Licensed under GNU GPL version 2 
-- https://www.gnu.org/licenses/gpl-2.0.html
cfg.videa_video_count=100
videa_static_url = 'http://videa.hu/static/video/'

-- csatornak/id, kategoriak/categoryname
function videa_updatefeed(feed,friendly_name)
	local rc=false

	local feed_url='http://videa.hu/rss/'..feed
	local feed_name='videa_'..string.gsub(feed,'/','_')
	local feed_m3u_path=cfg.feeds_path..feed_name..'.m3u'
	local tmp_m3u_path=cfg.tmp_path..feed_name..'.m3u'

	local x=rss_merge(rss_parse_feed(feed_url),rss_parse_m3u(feed_m3u_path),cfg.videa_video_count)

	if x then
		local dfd=io.open(tmp_m3u_path,'w+')
		if dfd then
			dfd:write('#EXTM3U name=\"',friendly_name or feed_name,'\" type=mp4 plugin=videa\n')

			for i,j in ipairs(x) do
				if j.logo then
					dfd:write('#EXTINF:0 logo=',j.logo,' ,',j.title,'\n',j.link,'\n')
				else
					dfd:write('#EXTINF:0 ,',j.title,'\n',j.link,'\n')
				end
			end
			dfd:close()

			if util.md5(tmp_m3u_path)~=util.md5(feed_m3u_path) then
				if os.execute(string.format('mv %s %s',tmp_m3u_path,feed_m3u_path))==0 then
					if cfg.debug>0 then print('videa feed \''..feed_name..'\' updated') end
					rc=true
				end
			else
				util.unlink(tmp_m3u_path)
			end
		end
	end
	return rc
end


function videa_sendurl(videa_url,range)
	--adult cookie hack
	http.user_agent(cfg.user_agent..'\r\nCookie: session_adult=1')
	local url=nil
	if plugin_sendurl_from_cache(videa_url,range) then return end
	local clip_page=plugin_download(videa_url)
	if clip_page then
		local video_json=string.match(clip_page,'new Video%((.-)%)%);')
		if video_json then
			local x=json.decode(video_json)
			if x.disk and x.fid and x.uid then
				url = videa_static_url..x.disk..'.'..x.fid..'.'..x.uid
				plugin_sendurl(videa_url,url,range)
			end
		end
	end
	if cfg.debug>0 then print('videa clip is not found') end
	plugin_sendfile('www/corrupted.mp4')
end

plugins['videa']={}
plugins.videa.name="videa"
plugins.videa.desc="csatornak/<i>channelid</i>, kategoriak/<i>categoryname</i>" 
plugins.videa.sendurl=videa_sendurl
plugins.videa.updatefeed=videa_updatefeed
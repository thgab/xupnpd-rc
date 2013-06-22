-- thgab74 at gmail.com
-- Licensed under GNU GPL version 2 
-- https://www.gnu.org/licenses/gpl-2.0.html
cfg.indavideo_video_count=100
indavideo_api_url='http://amfphp.indavideo.hu/SYm0json.php/player.playerHandler.getVideoData/'

-- user/username, channel/channelname
function indavideo_updatefeed(feed,friendly_name)
	local rc=false

	local feed_url='http://indavideo.hu/rss/'..feed
	local feed_name='indavideo_'..string.gsub(feed,'/','_')
	local feed_m3u_path=cfg.feeds_path..feed_name..'.m3u'
	local tmp_m3u_path=cfg.tmp_path..feed_name..'.m3u'

	local x=rss_merge(rss_parse_feed(feed_url),rss_parse_m3u(feed_m3u_path),cfg.indavideo_video_count)

	if x then
		local dfd=io.open(tmp_m3u_path,'w+')
		if dfd then
			dfd:write('#EXTM3U name=\"',friendly_name or feed_name,'\" type=mp4 plugin=indavideo\n')

			for i,j in ipairs(x) do
				if j.logo then
					dfd:write('#EXTINF:0 logo=',j.logo,' ,',j.title,'\n',j.link,'\n')
				else
					dfd:write('#EXTINF:0 ,',j.title,'\n',j.link,'\n')
				end
			end
			dfd:close()

			if util.md5(tmp_m3u_path)~=util.md5(feed_m3u_path) then
				if os.rename(tmp_m3u_path,feed_m3u_path) then
					if cfg.debug>0 then print('Indavideo feed \''..feed_name..'\' updated') end
					rc=true
				end
			else
				util.unlink(tmp_m3u_path)
			end
		end
	end
	return rc
end

function indavideo_sendurl(indavideo_url,range)
	local url=nil
	if plugin_sendurl_from_cache(indavideo_url,range) then return end
	local tokenized_url=indavideo_url..'?token='..util.md5_string_hash(indavideo_url)
	if cfg.debug>0 then print('indavideo URL: '..tokenized_url) end
	url=indavideo_get_video_url(tokenized_url)
	if url then
		if cfg.debug>0 then print('indavideo Real URL: '..url) end
		plugin_sendurl(indavideo_url,url,range)
	else
		if cfg.debug>0 then print('indavideo clip is not found') end
		plugin_sendfile('www/corrupted.mp4')
	end
end

function indavideo_get_video_url(indavideo_url)
	local url=nil
	local clip_page=plugin_download(indavideo_url)
	if clip_page then
		local video_hash=string.match(clip_page,'id="emb_hash" type="hidden" value="(.-)"')
		if video_hash then
			if cfg.debug>0 then print('hash'..video_hash) end
			local x=json.decode(plugin_download(indavideo_api_url..video_hash))
			if not x or not x.success or not x.data.video_files then return nil end
			return x.data.video_files[table.getn(x.data.video_files)]
		else
			if cfg.debug>0 then print('indavideo hash not found') end
			return nil
		end
	else
		if cfg.debug>0 then print('indavideo clip is not found') end
		return nil
	end
end

plugins['indavideo']={}
plugins.indavideo.name="indavideo"
plugins.indavideo.desc="user/<i>username</i>, channel/<i>channelname</i>"
plugins.indavideo.sendurl=indavideo_sendurl
plugins.indavideo.updatefeed=indavideo_updatefeed

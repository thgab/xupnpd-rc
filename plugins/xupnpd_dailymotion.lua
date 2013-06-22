-- thgab74 at gmail.com
-- Licensed under GNU GPL version 2 
-- https://www.gnu.org/licenses/gpl-2.0.html

dailymotion_api_url='http://www.dailymotion.com/sequence/full/'
dailymotion_feedapi_url='http://www.dailymotion.com/rss/'
dailymotion_formats={ ['1080p']='hd1080URL',['720p']='hd720URL',['hq']='hqURL',['sd']='sdURL',['ld']='ldURL'}
cfg.dailymotion_video_count = 100


function dm_rss_parse_feed(url,logo_regexp)
    local t={}

    local feed_data=http.download(url)

    if not feed_data then return t end

    if not logo_regexp then logo_regexp='url="(.-)"' end

    local x=xml.find('rss/channel',xml.decode(feed_data))

    feed_data=nil

    if x and x['@elements'] then
        local idx=1
        for i,j in ipairs(x['@elements']) do
            if j['@name']=='item' then
                local title=nil if j.title then title=j.title['@value'] end
                local link =nil if j.player then link=string.match(j.player['@attr'],logo_regexp) end
                local logo =nil if j.thumbnail then logo=string.match(j.thumbnail['@attr'],logo_regexp) end
                if title and link then
                    t[idx]={ ['title']=title, ['link']=link, ['logo']=logo }
                    idx=idx+1
                end
            end
        end
    end
    return t
end


function dailymotion_updatefeed(feed,friendly_name)
	local rc=false

	local feed_url=dailymotion_feedapi_url..feed
	local feed_name='dailymotion_'..string.gsub(feed,'/','_')
	local feed_m3u_path=cfg.feeds_path..feed_name..'.m3u'
	local tmp_m3u_path=cfg.tmp_path..feed_name..'.m3u'

	local x=rss_merge(dm_rss_parse_feed(feed_url),rss_parse_m3u(feed_m3u_path),cfg.dailymotion_video_count)

	if x then
		local dfd=io.open(tmp_m3u_path,'w+')
		if dfd then
			dfd:write('#EXTM3U name=\"',friendly_name or feed_name,'\" type=mp4 plugin=dailymotion\n')

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
					if cfg.debug>0 then print('Dailymotion feed \''..feed_name..'\' updated') end
					rc=true
				end
			else
				util.unlink(tmp_m3u_path)
			end
		end
	end
	return rc
end

function dailymotion_sendurl(dailymotion_url,range)
	local url=nil
	local real_url = dailymotion_get_video_url(dailymotion_url)
	if cfg.debug>0 then print('dailymotion url: '..real_url) end
	if real_url then
		plugin_sendurl(dailymotion_url,real_url,range)
	else
		plugin_sendfile('www/corrupted.mp4')
	end
end

function dailymotion_get_video_url(dailymotion_url)
	local url=nil
	local video_hash=string.match(dailymotion_url,'.-/video/([^_#]+)_-.-$')
	if video_hash then
		local clip_page=plugin_download(dailymotion_api_url..video_hash)
		if clip_page then
			local x=json.decode(clip_page)
			video_url = dailymotion_sequence_parser(x)
			print(clip_page)
			x = nil
			if video_url then
				return video_url
			end
		end
		if cfg.debug>0 then print('dailymotion clip is not found') end
		return nil
	else
		if cfg.debug>0 then print('dailymotion hash not found') end
	end
end

function dailymotion_sequence_parser(x)
	for i,j in ipairs(x.sequence) do
	   	if j.name == 'root' then
    		for ii,jj in ipairs(x.sequence[i].layerList) do
        		if jj.name == 'background' then
            		for iii,jjj in ipairs(x.sequence[i].layerList[ii].sequenceList) do
            			if jjj.name == 'main' then
                			for iiii,jjjj in ipairs(x.sequence[i].layerList[ii].sequenceList[iii].layerList) do
            					if jjjj.name == 'video' then
                					return x.sequence[i].layerList[ii].sequenceList[iii].layerList[iiii].param.hqURL
            					end
        					end
            			end
        			end
       			end
       		end
       	end
   	end
   	return nil
end

plugins['dailymotion']={}
plugins.dailymotion.name="dailymotion"
plugins.dailymotion.desc="user/<i>username</i>/videos, user/<i>username</i>/favorites, playlist/<i>palylistid</i>/videos, channel/<i>channelname</i>/videos"
plugins.dailymotion.sendurl=dailymotion_sendurl
plugins.dailymotion.updatefeed=dailymotion_updatefeed

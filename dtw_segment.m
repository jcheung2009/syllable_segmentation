function [sm_ons sm_offs tm2 sp2 f2] = dtw_segment(smtemp,dtwtemplate,fs,varargin);
%performs spectrogram dtw using template and exemplar (smtemp). returns
%time in seconds into smtemp that corresponds to onsets and offsets of
%template
%the template has defined syll onsets/offsets; dtw will compare the spectral 
%feature at each time point in the template with the spectral feature in the
%exemplar. therefore, you can find the corresponding syll onsets/offsets in the exemplar 
%varargin{1} = 1, plot dtw example

%spectrogram params
NFFT = 512;
overlap = NFFT-10;
t=-NFFT/2+1:NFFT/2;
sigma=(1/1000)*fs;
w=exp(-(t/sigma).^2);

%extract the dtwtemplate spectrogram and ons/offs
temp = dtwtemplate.filtsong;
temp_ons=dtwtemplate.ons;
temp_offs=dtwtemplate.offs;
[sp f tm1] = spectrogram(temp,w,overlap,NFFT,fs);
indf = find(f>500 & f<10000);
f = f(indf);
temp = abs(sp(indf,:));
temp = temp./sum(temp,2);
temp_onind = NaN(length(temp_ons),1);temp_offind = NaN(length(temp_offs),1);
for m = 1:length(temp_ons)
    [~, temp_onind(m)] = min(abs(temp_ons(m)-tm1));
    [~, temp_offind(m)]=min(abs(temp_offs(m)-tm1));
end

%extract exemplar spectrogram 
filttemp = bandpass(smtemp,fs,500,10000,'hanningffir');
[sp2 f2 tm2] = spectrogram(filttemp,w,overlap,NFFT,fs);
indf = find(f2>500 & f2 <10000);
f2 = f2(indf);
sp2 = abs(sp2(indf,:));
sp2 = sp2./sum(sp2,2);

%dtw and find corresponding ons/offs to temp
sm_ons = NaN(length(temp_onind),1);sm_offs = NaN(length(temp_offind),1);
[dist ix iy] = dtw(temp,sp2);
alignedonind = [];alignedoffind = [];
for m = 1:length(temp_onind)
    ind = find(ix==temp_onind(m));
    ind = ind(ceil(length(ind)/2));
    alignedonind = [alignedonind; ind];
    sm_ons(m) = tm2(iy(ind));
    ind = find(ix==temp_offind(m));
    ind = ind(ceil(length(ind)/2));
    alignedoffind = [alignedoffind; ind];
    sm_offs(m) = tm2(iy(ind));
end

%plot dtw process
if ~isempty(varargin)
    figure;
    subplot(3,2,1);hold on;%template signal
    imagesc(tm1,f,log(abs(temp)));hold on;
    plot([temp_ons temp_ons],[500 10000],'g','linewidth',2);hold on;
    plot([temp_offs temp_offs],[500 10000],'g','linewidth',2);hold on;
    title('original template');axis tight
    h = get(gca);
    
    subplot(3,2,3);hold on;%exemplar signal
    imagesc(tm2,f2,log(abs(sp2)));hold on;
    plot([sm_ons sm_ons],[500 10000],'r','linewidth',2);hold on;
    plot([sm_offs sm_offs],[500 10000],'r','linewidth',2);hold on;
    title('original exemplar');axis tight
    y = get(gca,'xlim');
    if y(2) < h.XLim(2)
        set(gca,'xlim',h.XLim);
    elseif y(2) > h.XLim(2)
        h.XLim = y;
    end
    
    subplot(3,2,5);hold on;%overlaid signal
    maxlen = max([size(temp,2) size(sp2,2)]);
    temp = [temp NaN(size(temp,1),maxlen-size(temp,2))];
    sp2 = [sp2 NaN(size(sp2,1),maxlen-size(sp2,2))];
    overlaid = temp+sp2;
    if length(tm1) > length(tm2)
        imagesc(tm1,f,log(abs(overlaid)));
    else
        imagesc(tm2,f,log(abs(overlaid)));
    end
    title('overlaid original signals');axis tight
    
    subplot(3,2,2);hold on;%aligned template 
    newtm1 = [0:length(ix)-1]./fs;
    imagesc(newtm1,f,log(abs(temp(:,ix))));
    plot([newtm1(alignedonind)' newtm1(alignedonind)'],[500 10000],'g','linewidth',2);hold on;
    plot([newtm1(alignedoffind)' newtm1(alignedoffind)'],[500 10000],'g','linewidth',2);hold on;
    title('aligned template');axis tight
    
    subplot(3,2,4);hold on;%aligned exemplar 
    newtm2 = [0:length(iy)-1]./fs;
    imagesc(newtm2,f2,log(abs(sp2(:,iy))));
    plot([newtm2(alignedonind)' newtm2(alignedonind)'],[500 10000],'r','linewidth',2);hold on;
    plot([newtm2(alignedoffind)' newtm2(alignedoffind)'],[500 10000],'r','linewidth',2);hold on;
    title('aligned exemplar');axis tight
    
    subplot(3,2,6);hold on;%overlaid aligned
    overlaid = sp2(:,iy)+temp(:,ix);
    imagesc(newtm1,f,log(abs(overlaid)));
    title('overlaid aligned signals');axis tight
end
    
    
    
 
    
-- Pixel rectangles inside ScreenGui's inset-safe root. Pure for device tests.
local Layout={}
function Layout.compute(width,height)
	assert(width>=240 and height>=240,"unsupported viewport")
	local short=height<480
	local guideWidth=math.min(width-24,440)
	local guideHeight=if short then 100 else 112
	return {
		guide={x=(width-guideWidth)/2,y=if short then height-guideHeight-8 else 176,w=guideWidth,h=guideHeight},
		challenge={x=(width-math.min(width*.9,438))/2,y=(height-250)/2,w=math.min(width*.9,438),h=250},
		settings={x=(width-math.min(width*.94,450))/2,y=(height-math.min(height*.94,480))/2,w=math.min(width*.94,450),h=math.min(height*.94,480)},
		rematch={x=(width-math.min(236,width-32))/2,y=height-64,w=math.min(236,width-32),h=52},
	}
end
return Layout
